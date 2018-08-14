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
        context => 'dashboard/profile',
        user    => resultset('User')->find( session('user_id') ),
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
                template_file => 'verify_new_email.tt',
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
            return redirect uri_for('/dashboard/profile', { error => 'verify_new_email_failed' });
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

sub change_user_state {
    my ( $id, $state ) = @_;
    my $user = resultset('User')->find($id);

    # FIXME: these methods check if the user is authorized
    #        we should put this action elsewhere
    eval {
        $user->$state();
        1;
    } or do {

        # FIXME: don't just report the error, show the user as well
        #        GH#9
        my $error = $@ || 'Zombie error';
        error $error;
    };

    return uri_for('/dashboard/users');
}

prefix '/dashboard/users' => sub {
    get '/?' => needs_permission view_user => sub {
        my $page       = query_parameters->{'page'} || 1;
        my $status     = query_parameters->{'status'};
        my $nr_of_rows = 5;

        my $search_parameters = {};

        # this is very confusing, but basically:
        # - if we have a status, use that
        # - if we don't AND it's not multiuser, get non-pending only
        # (conclusion: multiuser allows seeing pending users)
        if ($status) {
            $search_parameters->{'status'} = $status;
        } elsif ( !config->{'multiuser'} ) {
            $search_parameters->{'status'} = { '!=' => 'pending' };
        }

        my $search_options = {
            order_by => { -desc => 'registered_at' },
            rows     => $nr_of_rows,
            page     => $page,
        };

        my @users = resultset('User')
            ->search( $search_parameters, $search_options );
        my $count = resultset('View::Count::StatusUser')->first;

        my ( $all, $activated, $deactivated, $suspended, $pending )
            = $count->get_all_status_counts;

        # we also want to change the count of total users
        # and if it's not multiuser, we remove pending users from the count
        if ( !config->{'multiuser'} ) {
            my $num_pending_users
                = resultset('User')->search( { status => 'pending' }, )
                ->count;

            $all -= $num_pending_users;
        }

        # FIXME: temporary override of $all because "ugh"
        #        Uses the View::Count::StatusPost
        #        which doesn't allow specifying an optional post status
        #        why have two methods instead of a method with a parameter?
        $status and $all = $count->get_status_count($status);

        my $action_url = '/dashboard/users?status=' . uri_escape($status);

        # Calculate the next and previous page link
        my $total_pages = get_total_pages( $all, $nr_of_rows );
        my ( $previous_link, $next_link )
            = get_previous_next_link( $page, $total_pages, $action_url );

        # Generating the pagination navigation
        my $total_users    = $all;
        my $posts_per_page = $nr_of_rows;
        my $current_page   = $page;
        my $pages_per_set  = 7;
        my $pagination
            = generate_pagination_numbering( $total_users, $posts_per_page,
            $current_page, $pages_per_set );

        template '/admin/users/list' => {
            users         => \@users,
            all           => $all,
            activated     => $activated,
            deactivated   => $deactivated,
            suspended     => $suspended,
            pending       => $pending,
            page          => $page,
            next_link     => $next_link,
            previous_link => $previous_link,
            action_url    => $action_url,
            pages         => $pagination->pages_in_set
        } => { layout => 'admin' };
    };

    foreach my $state (qw<activate deactivate suspend>) {
        get "/$state/:id" => needs_permission update_user => sub {
            my $new_url
                = change_user_state( route_parameters->{'id'}, $state, );

            redirect $new_url;
        };
    }

    # approve pending users (FIXME: rename to "approve"?)
    get '/allow/:id' => needs_permission allow_user => sub {
        my $user_id = route_parameters->{'id'};
        my $user    = resultset('User')->find($user_id)
            or redirect uri_for('/dashboard/users');

        $user->allow();

        sendmail({
            name          => $user->name,
            email_address => $user->email,
            template_file => 'welcome.tt',
            subject       => 'Welcome to PearlBee', # FIXME
            variables     => {
                role       => $user->role,
                username   => $user->username,
                name       => $user->name,
                app_url    => config->{'app_url'},
                blog_name  => config->{'blog_name'},
                signature  => '',
                allowed    => 1,
            }
        });

        redirect uri_for('/dashboard/users');
    };

    get '/add' => sub {
        template 'admin/users/add', {}, { layout => 'admin' };
    };

    post '/add' => sub {
        eval {
            my $dt = DateTime->now;
            $dt->set_time_zone( config->{timezone} );

            my $password   = random_string('Ccc!cCn');
            my $params     = body_parameters;
            my $username   = $params->{'username'};
            my $email      = $params->{'email'};
            my $name       = $params->{'name'};
            my $role       = $params->{'role'};

            resultset('User')->create(
                {
                    username      => $username,
                    password      => $password,
                    name          => $name,
                    role          => $role,
                    email         => $email,
                }
            );

            sendmail({
                template_file => 'welcome.tt',
                name          => $name,
                email_address => $email,
                subject       => 'Welcome to PearlBee', # FIXME
                role          => $role,
                username      => $username,
                password      => $password,
                app_url       => config->{'app_url'},
                blog_name     => config->{'blog_name'},
                signature     => '',
            });

            1;
        } or do {
            my $error = $@ || 'Zombie error';
            error $error; # FIXME GH#9
            return template 'admin/users/add' => { warning =>
                    'Something went wrong. Please contact the administrator.'
            } => { layout => 'admin' };
        };

        template 'admin/users/add' => { success =>
                'The user was added succesfully and will be activated after he logs in.'
        } => { layout => 'admin' };
    };
};

1;
