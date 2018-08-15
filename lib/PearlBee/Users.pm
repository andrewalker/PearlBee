package PearlBee::Users;

# ABSTRACT: User-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Mailer::PearlBee;
use PearlBee::Helpers::Captcha;
use DateTime;

get '/sign-up' => sub {
    PearlBee::Helpers::Captcha::new_captcha_code();
    template signup => {  } => { layout => 'clear' };
};

get '/sign-up/confirm' => sub {
    my $token = query_parameters->{'token'};

    my $rs = resultset('RegistrationToken');
    my $token_result = $rs->find({ token => $token, voided_at => undef });

    if (!$token_result) {
        # should we log?
        return template 'signup_confirm_email' => { not_found => 1 };
    }

    if ($token_result->user->verified_email) {
        # should we log?
        return template 'signup_confirm_email' => { not_pending => 1 };
    }

    $token_result->user->update({ verified_email => 1 });
    $token_result->update({ voided_at => \'current_timestamp' });

    template 'signup_confirm_email' => { success => 1 } => { layout => 'clear' };
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
            { %{$template_params}, warning => $warning, } => { layout => 'clear' };
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
        role          => 'author'
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
                token => $user->new_random_token('verify-email-address'),
            }
        });
        1;
    } or do {
        return $failed_login->('Could not send the email: ' . $@);
    };

    template notify => {
        success => 'Please check your inbox and confirm your email address'
    } => { layout => 'clear' };
};

get '/login' => sub {
    my $failure = query_parameters->{'invalid'}
                ? 'Invalid login credentials'
                : query_parameters->{'banned'}
                ? 'Your account has been banned'
                : query_parameters->{'pending'}
                ? 'Your e-mail address has not been verified yet'
                : ''
                ;

    $failure and return template
        login => { warning => $failure },
        { layout => 'clear' };

    session('user_id') and redirect '/dashboard';
    template
        login => {},
        { layout => 'clear' };
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

    $user->verified_email
        or redirect '/login?pending=1';

    $user->banned
        and redirect '/login?banned=1';

    $user->update({ last_login => \'now()' });
    session user_id => $user->id;

    redirect('/dashboard');
};

get '/forgot-password' => sub {
    PearlBee::Helpers::Captcha::new_captcha_code();
    template 'forgot_password' => {
        not_found     => query_parameters->{'not_found'},
        not_activated => query_parameters->{'not_activated'},
        failed_email  => query_parameters->{'failed_email'},
        wrong_captcha => query_parameters->{'wrong_captcha'},
        sent          => query_parameters->{'sent'}
    } => { layout => 'clear' };
};

post '/forgot-password' => sub {
    my $username = params->{'username'};

    PearlBee::Helpers::Captcha::check_captcha_code( body_parameters->{'secret'} )
        or return redirect '/forgot-password?wrong_captcha=1';

    my $user = resultset('User')->single({
        -or => [
            username => $username,
            email    => $username,
        ],
    }) or redirect '/forgot-password?not_found=1';

    $user->verified_email
        or redirect '/forgot-password?not_activated=1';

    eval {
        sendmail({
            template_file => 'reset_password.tt',
            name          => ($user->name || $user->username),
            email_address => $user->email,
            subject       => 'Reset password',
            variables     => {
                name  => ($user->name || $user->username),
                token => $user->new_random_token('reset-password'),
            }
        });
        1;
    } or do {
        error "Failed to send e-mail: $@";
        return redirect '/forgot-password?failed_email=1'
    };

    redirect '/forgot-password?sent=1';
};

get '/reset-password' => sub {
    my $token = query_parameters->{'token'}
        or return redirect '/forgot-password';

    my $rs = resultset('RegistrationToken');
    my $token_result = $rs->single({ token => $token, reason => 'reset-password' });

    if ( ( !$token_result || $token_result->voided_at )
        && !query_parameters->{'done'} )
    {
        # should we log? add query param?
        return redirect '/forgot-password';
    }

    template 'reset_password' => {
        user           => $token_result->user,
        token          => $token,
        no_match       => query_parameters->{'no_match'},
        empty_password => query_parameters->{'empty_password'},
        done           => query_parameters->{'done'},
    } => { layout => 'clear' };
};

post '/reset-password' => sub {
    my $token = params->{'token'}
        or return redirect uri_for('/forgot-password');

    my $pass = body_parameters->{'password'}
        or return redirect uri_for('/reset-password', { empty_password => 1, token => $token });

    $pass eq body_parameters->{'confirm_password'}
        or return redirect uri_for('/reset-password', { no_match => 1, token => $token });

    my $rs = resultset('RegistrationToken');
    my $token_result = $rs->single({ token => $token, voided_at => undef, reason => 'reset-password' });

    if (!$token_result) {
        # should we log? add query param?
        return redirect uri_for('/forgot-password');
    }

    $token_result->user->update({ password => $pass });
    $token_result->update({ voided_at => \'now()' });

    redirect uri_for('/reset-password', { done => 1, token => $token });
};

get '/logout' => sub {
    app->destroy_session;
    redirect '/?logout=1';
};

1;
