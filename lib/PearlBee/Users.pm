package PearlBee::Users;

# ABSTRACT: User-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Mailer::PearlBee;
use PearlBee::Helpers::Captcha;
use DateTime;

get '/sign-up' => sub {
    PearlBee::Helpers::Captcha::new_captcha_code();
    template signup => {};
};

get '/sign-up/confirm' => sub {
    my $token = query_parameters->{'token'};

    my $rs = resultset('RegistrationToken');
    my $token_result = $rs->find({ token => $token, voided_at => undef });

    if (!$token_result) {
        # should we log?
        return template 'signup_confirm_email' => { not_found => 1 };
    }

    if ($token_result->user->status ne 'pending') {
        # should we log?
        return template 'signup_confirm_email' => { not_pending => 1 };
    }

    $token_result->user->update({ status => 'activated' });
    $token_result->update({ voided_at => \'current_timestamp' });

    template 'signup_confirm_email' => { success => 1 };
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

    resultset('User')->count( { email => $email } )
        and return $failed_login->("Email address already in use.");

    resultset('User')->count( { username => $username } )
        and return $failed_login->("Username already in use.");

    $params->{'password'} ne $params->{'confirm_password'}
        and return $failed_login->("Passwords don't match.");

    my $user = resultset('User')->create({
        username      => $username,
        password      => $params->{'password'},
        email         => $email,
        role          => 'author',
        status        => 'pending'
    });

#   Trigger a notify_new_user alert, that admin's can subscribe?
#   my $first_admin = resultset('User')->single({
#       role   => 'admin',
#       status => 'activated',
#   });
#   sendmail({
#       template_file => 'new_user.tt',
#       name          => $first_admin->name,
#       email_address => $first_admin->email,
#       subject       => 'A new user applied as an author to the blog',
#       variables     => {
#           name       => $params->{'name'},
#           username   => $params->{'username'},
#           email      => $params->{'email'},
#       },
#   });

    eval {
        sendmail({
            template_file => 'activation_email.tt',
            name          => $params->{'username'},
            email_address => $params->{'email'},
            subject       => 'Please confirm your email address',
            variables     => {
                name  => $params->{'username'},
                token => $user->new_random_token,
            }
        });
        1;
    } or do {
        return $failed_login->('Could not send the email: ' . $@);
    };

    template notify => { success =>
            'Please check your inbox and confirm your email address' };
};

get '/login' => sub {
    my $failure = query_parameters->{'invalid'}
                ? 'Invalid login credentials'
                : query_parameters->{'suspended'}
                ? 'Your account has been suspended'
                : query_parameters->{'pending'}
                ? 'Your e-mail address has not been verified yet'
                : ''
                ;

    $failure and return template
        login => { warning => $failure },
        { layout => 'admin' };

    session('user_id') and redirect '/dashboard';
    template
        login => {},
        { layout => 'admin' };
};

post '/login' => sub {
    my $password = params->{'password'};
    my $username = params->{'username'};

    my $user = resultset('User')->single({
        -or => [
            username => $username,
            email    => $username,
        ],
    }) or redirect '/login?invalid=1';

    $user->check_password($password)
        or redirect '/login?invalid=1';

    $user->status eq 'pending'
        and redirect '/login?pending=1';

    $user->status eq 'suspended'
        and redirect '/login?suspended=1';

    session user_id => $user->id;

    redirect('/dashboard');
};

get '/logout' => sub {
    app->destroy_session;
    redirect '/?logout=1';
};

1;
