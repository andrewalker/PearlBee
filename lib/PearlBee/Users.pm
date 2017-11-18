package PearlBee::Users;

# ABSTRACT: User-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use PearlBee::Helpers::Captcha;
use String::Random qw<random_string>;

use DateTime;
use Email::Template;

get '/sign-up' => sub {
    PearlBee::Helpers::Captcha::new_captcha_code();
    template signup => {};
};

post '/sign-up' => sub {
    my $params          = body_parameters;
    my $template_params = {
        username   => $params->{'username'},
        email      => $params->{'email'},
        first_name => $params->{'first_name'},
        last_name  => $params->{'last_name'},
    };

    my $failed_login = sub {
        my $warning = shift;
        error "Error in sign-up attempt: $warning";
        PearlBee::Helpers::Captcha::new_captcha_code();
        return template signup =>
            { %{$template_params}, warning => $warning, };
    };

    my $username = $params->{'username'}
        or return $failed_login->('Please provide a username.');

    my $email = $params->{'email'}
        or return $failed_login->('Please provide an email.');

    PearlBee::Helpers::Captcha::check_captcha_code( $params->{'secret'} )
        or return $failed_login->('Invalid secret code.');

    eval {
        resultset('User')->search( { email => $email } )->first
            and die "Email address already in use.\n";

        resultset('User')->search( { username => $username } )->first
            and die "Username already in use.\n";

        # Create the user

        # Set the proper timezone
        my $dt       = DateTime->now;
        $dt->set_time_zone( config->{timezone} );

        my $password = random_string('Ccc!cCn');

        resultset('User')->create(
            {
                username      => $username,
                password      => $password,
                email         => $email,
                first_name    => $params->{'first_name'},
                last_name     => $params->{'last_name'},
                register_date => join( ' ', $dt->ymd, $dt->hms ),
                role          => 'author',
                status        => 'pending'
            }
        );

        # Notify the author that a new comment was submited
        my $first_admin = resultset('User')->search(
            {
                role   => 'admin',
                status => 'activated',
            }
        )->first;

        my $email_template = config->{'email_templates'} . 'new_user.tt';
        Email::Template->send(
            $email_template => {
                From    => config->{'default_email_sender'},
                To      => $first_admin->email,
                Subject => 'A new user applied as an author to the blog',

                tt_vars => {
                    first_name => $params->{'first_name'},
                    last_name  => $params->{'last_name'},
                    username   => $params->{'username'},
                    email      => $params->{'email'},
                    signature  => config->{'email_signature'},
                    blog_name  => session('blog_name'),
                    app_url    => session('app_url'),
                }
            }
        ) or die "Could not send the email\n";

        1;
    } or do {
        return $failed_login->( $@ || 'Unknown error' );
    };

    template notify => { success =>
            'The user was created and it is waiting for admin approval.' };
};

get '/login' => sub {

    # if registered, just display the dashboard
    my $failure = query_parameters->{'failure'};
    $failure and return template
        login => { warning => $failure, },
        { layout => 'admin' };

    session('user_id') and redirect '/dashboard';
    template
        login => {},
        { layout => 'admin' };
};

post '/login' => sub {
    my $password = params->{password};
    my $username = params->{username};

    my $user = resultset('User')->find(
        {
            username => $username,
            -or      => [
                status => 'activated',
                status => 'deactivated'
            ]
        }
    ) or redirect '/login?failed=1';

    $user->check_password($password)
        or redirect '/login?failed=1';

    session user_id => $user->id;

    redirect('/dashboard');
};

get '/logout' => sub {
    app->destroy_session;
    redirect '/?logout=1';
};

1;
