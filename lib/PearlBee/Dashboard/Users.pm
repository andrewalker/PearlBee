package PearlBee::Dashboard::Users;
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Tiny;
use Dancer2::Plugin::Auth::PearlBee;
use Dancer2::Plugin::Mailer::PearlBee;

use PearlBee::Helpers::Pagination qw<
    get_total_pages
    get_previous_next_link
    generate_pagination_numbering
>;

use String::Random qw<random_string>;

use DateTime;
use URI::Escape;

config->{'plugins'}{'Auth::Tiny'}{'logged_in_key'} = 'user_id';

get '/dashboard/profile' => needs login => sub {
    my $tmpl_data = {
        context           => 'dashboard/profile',
        user              => resultset('User')->find( session('user_id') ),
        new_authors_count => new_authors_count(),
    };

    if (query_parameters->{'error'}) {
        $tmpl_data->{user} = session 'form_data';
        session( form_data => undef );
        $tmpl_data->{error} = query_parameters->{'error'};
    }

    if (query_parameters->{'done'}) {
        $tmpl_data->{updated_profile} = 1;
    }

    template 'dashboard/profile' => $tmpl_data => { layout => 'dashboard' };
};

# FIXME: this is a big copy&paste from PearlBee::API::Users
# we need to create a PearlBee::Model::Users
post '/dashboard/profile' => needs login => sub {
    my $user_id = session 'user_id';
    my $user = resultset('User')->find($user_id);
    my $updated_email = 0;

    my ($name, $email);
    if (($name = body_parameters->{'name'}) && ($name ne $user->name)) {
        $user->update({ name => $name });
    }
    if (($email = body_parameters->{'email'}) && ($email ne $user->email)) {
        if (resultset('User')->count( { email => $email } )) {
            return redirect uri_for('/dashboard/profile', { error => 'email_conflict' });
        }

        $user->update({ email => $email, verified_email => 0 });
        eval {
            sendmail({
                template_file => 'verify_new_email.hbs',
                name          => $user->username,
                email_address => $email,
                subject       => 'Please confirm your email address',
                variables     => {
                    name  => $user->username,
                    token => $user->new_random_token('verify-email-address'),
                }
            });
            1;
        } or do {
            error 'Could not send the email: ' . $@;
        };

        $updated_email++;
    }
    if (my $current_password = body_parameters->{'current_password'}) {
        $user->check_password($current_password)
            and return redirect uri_for('/dashboard/profile', { error => 'wrong_current_password' });

        my $new = body_parameters->{'new_password'}
            and return redirect uri_for('/dashboard/profile', { error => 'new_password_missing' });

        $new eq body_parameters->{'confirm_password'}
            and return redirect uri_for('/dashboard/profile', { error => 'passwords_dont_match' });

        $user->update({ password => $new });
    }


    my $args = { done => 1 };
    if ($updated_email) {
        $args->{updated_email} = 1;
    }

    return redirect uri_for('/dashboard/profile', $args);
};

get '/dashboard/verify-new-authors' => needs 'login' => sub {
    if (!var('user')->verified_by_peers) {
        return redirect uri_for('/dashboard');
    }

    my @users = resultset('User')->search(
        { verified_by_peers => 0, verified_email => 1, banned => 0 },
        { order_by => { -desc => 'registered_at' } }
    )->all;

    template 'dashboard/verify-new-authors' => {
        users => [
            map {
                +{
                    avatar        => $_->avatar,
                    id            => $_->id,
                    username      => $_->username,
                    email         => $_->email,
                    registered_at => $_->registered_at,
                }
            } @users
        ],
        context => 'dashboard/verify-new-authors',
        new_authors_count => new_authors_count(),
    } => { layout => 'dashboard' };
};

sub new_authors_count {
    resultset('User')
        ->count({ verified_by_peers => 0, banned => 0, verified_email => 1 });
}

1;
