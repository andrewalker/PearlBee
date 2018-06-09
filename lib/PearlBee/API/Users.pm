package PearlBee::API::Users;

# ABSTRCT: Posts-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Tiny;
use Dancer2::Plugin::Mailer::PearlBee;

get '/api/user' => needs 'login' => sub {
    my $user_id = session 'user_id';

    my $user = resultset('User')->find($user_id);

    send_as JSON => {
        user => {
            name              => $user->name,
            username          => $user->username,
            email             => $user->email,
            role              => $user->role,
            verified_email    => $user->verified_email,
            verified_by_peers => $user->verified_by_peers,
            post_count        => $user->posts->search({status => 'published'})->count,
            registered_at     => $user->registered_at->strftime("%F %T%z"),
            $user->last_login
                ? ( last_login => $user->last_login->strftime("%F %T%z") )
                : (),
        },
    };
};

patch '/api/user' => needs 'login' => sub {
    if (request->header('Content-Type') ne 'application/merge-patch+json') {
        status 'not_acceptable';
        send_as JSON => {
            error => 'Not acceptable. Use application/merge-patch+json, according to RFC 7396'
        };
    }

    my $user_id = session 'user_id';
    my $user = resultset('User')->find($user_id);
    my $json = decode_json( request->body );
    my $updated = 0;

    if (my $name = $json->{name}) {
        $user->update({ name => $name });
        $updated++;
    }
    if (my $email = $json->{email}) {
        if (resultset('User')->count( { email => $email } )) {
            status 'conflict';
            send_as JSON => { error => 'email already in use' };
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
            status 'internal_server_error';
            return '';
        };

        $updated++;
    }

    if ($updated) {
        status 'no_content';
        return '';
    }
    else {
        status 'bad_request';
        send_as JSON => { error => 'Bad Request' };
    }
};

# XXX:
# This is not RESTful; it's hard to represent change password in a RESTful and
# secure way. If we treat it like any other field, we can use the patch method
# according to RFC 7396. But then, we can't use current_password and
# confirm_password. We could check confirm_password only client side, but
# that's fragile. Even worse, we'd have no way to check current_password, we'd
# have to rely on the session. The simplest solution for now is to have this
# be this unique snowflake.
post '/api/user/change-password' => needs 'login' => sub {
    if (request->header('Content-Type') ne 'application/json') {
        status 'not_acceptable';
        send_as JSON => {
            error => 'Not acceptable. Use application/json.'
        };
    }

    my $user_id = session 'user_id';
    my $user    = resultset('User')->find($user_id);
    my $json    = decode_json( request->body );

    $user->check_password($json->{current_password})
        or return send_as_bad_request({ error => q/"current_password" is not correct/});

    my $new = $json->{'new_password'}
        or return send_as_bad_request({ error => q/"new_password" missing/});

    $new eq $json->{'confirm_password'}
        or return send_as_bad_request({ error => q/"new_password" doesn't match "confirm_password"/});

    $user->update({ password => $new });

    status 'no_content';
    return '';

    sub send_as_bad_request {
        status 'bad_request';
        send_as JSON => $_[0];
    }
};


get '/api/user' => sub {
    my $user_id = session 'user_id';

    my $user = resultset('User')->find($user_id);

    if (!$user) {
        status 'not_found';
        send_as JSON => { error => "not found" };
    }

    send_as JSON => {
        user => {
            name              => $user->name,
            username          => $user->username,
            email             => $user->email,
            role              => $user->role,
            verified_email    => $user->verified_email,
            verified_by_peers => $user->verified_by_peers,
            post_count        => $user->posts->search({status => 'published'})->count,
            registered_at     => $user->registered_at->strftime("%F %T%z"),
            $user->last_login
                ? ( last_login => $user->last_login->strftime("%F %T%z") )
                : (),
        },
    };
};

get '/api/user/:user' => sub {
    my $username = route_parameters->{'user'};

    my $user = resultset('User')->search({
        username => $username
    })->first;

    if (!$user) {
        status 'not_found';
        send_as JSON => { error => "not found" };
    }

    send_as JSON => {
        user => {
            name              => $user->name,
            username          => $user->username,
            role              => $user->role,
            verified_email    => $user->verified_email,
            verified_by_peers => $user->verified_by_peers,
            post_count        => $user->posts->search({status => 'published'})->count,
        },
    };
};


1;
