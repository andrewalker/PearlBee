package PearlBee::Users;

# ABSTRACT: User-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Mailer::PearlBee;
use PearlBee::Helpers::Captcha;
use String::Random qw<random_string>;
use DateTime;

get '/sign-up' => sub {
    PearlBee::Helpers::Captcha::new_captcha_code();
    template signup => {};
};

post '/sign-up' => sub {
    my $params          = body_parameters;
    my $template_params = {
        username   => $params->{'username'},
        email      => $params->{'email'},
        name       => $params->{'name'},
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

    resultset('User')->search( { email => $email } )->first
        and return $failed_login->("Email address already in use.");

    resultset('User')->search( { username => $username } )->first
        and return $failed_login->("Username already in use.");

    # Set the proper timezone
    my $dt       = DateTime->now;
    $dt->set_time_zone( config->{timezone} );

    my $password = random_string('Ccc!cCn');

    resultset('User')->create(
        {
            username      => $username,
            password      => $password,
            email         => $email,
            name          => $params->{'name'},
            role          => 'author',
            status        => 'pending'
        }
    );

    my $first_admin = resultset('User')->search({
        role   => 'admin',
        status => 'activated',
    })->first;

    eval {
        sendmail({
            template_file => 'new_user.tt',
            name          => $first_admin->name,
            email_address => $first_admin->email,
            subject       => 'A new user applied as an author to the blog',
            variables     => {
                name       => $params->{'name'},
                username   => $params->{'username'},
                email      => $params->{'email'},
                signature  => '',
                blog_name  => config->{'blog_name'},
                app_url    => config->{'app_url'},
            },
        });
        1;
    } or do {
        return $failed_login->('Could not send the email');
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
