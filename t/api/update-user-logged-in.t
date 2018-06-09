use PearlBee::Test;
use JSON::MaybeXS;
use HTML::Entities qw(decode_entities);

my $urs = schema->resultset('User');
my $prs = schema->resultset('Post');
my $trs = schema->resultset('PostTag');

my %Cred = (
    'johndoe-update-user' => 'type-mane-eng-kiva-hobby-jason-blake-ripe-marco',
    'johndoe-new-user'    => 'eng-kiva-hobby-type-mane-jason-blake-ripe-marco',
);

sub insert_data {
    $urs->search( { email => 'johndoe-update-user-other-email@gmail.com' } )->delete;
    $urs->search( { email => 'johndoe-update-user@gmail.com' } )->delete;
    $urs->search( { email => 'johndoe-new-user@gmail.com' } )->delete;
    my $existing = $urs->create({
        username          => 'johndoe-update-user',
        email             => 'johndoe-update-user@gmail.com',
        password          => 'type-mane-eng-kiva-hobby-jason-blake-ripe-marco',
        name              => 'John Doe Update User 1',
        role              => 'author',
        verified_email    => 1,
        verified_by_peers => 1,
    });
    my $new = $urs->create({
        username       => 'johndoe-new-user',
        email          => 'johndoe-new-user@gmail.com',
        password       => 'eng-kiva-hobby-type-mane-jason-blake-ripe-marco',
        name           => 'John Doe New User 1',
        role           => 'author',
        verified_email => 0,
    });
}

sub login {
    my ($mech, $user, $password) = @_;

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => $user,
                password => $password,
            },
        },
        'Was able to submit form'
    );

    $mech->content_like(
        qr{Welcome.*$user},
        'User is logged in'
    );

    like($mech->uri->path, qr{^/dashboard}, 'user was redirected to dashboard');
}

sub cant_login {
    my ($mech, $user, $password) = @_;

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => $user,
                password => $password,
            },
        },
        'Was able to submit form'
    );

    $mech->content_unlike(
        qr{Welcome.*$user},
        'User is not logged in'
    );

    unlike($mech->uri->path, qr{^/dashboard}, 'user was not redirected to dashboard');
}

subtest 'patch name' => sub {
    insert_data();
    my $mech = mech;
    login($mech, 'johndoe-update-user', $Cred{'johndoe-update-user'});

    my $req = HTTP::Request->new( PATCH => '/api/user' );
    $req->content_type( 'application/merge-patch+json' );
    $req->content( encode_json({ name => 'John Doe Update User 2' }) );

    my $res = $mech->request($req);
    ok($res->is_success, 'was able to request PATCH /api/user');
    $mech->get_ok('/api/user', 'retrieve data back' );
    my $data = decode_json($mech->content);
    is($data->{user}{name}, 'John Doe Update User 2', 'name was changed');
};

subtest 'patch username' => sub {
    insert_data();
    my $mech = mech;
    login($mech, 'johndoe-update-user', $Cred{'johndoe-update-user'});

    my $req = HTTP::Request->new( PATCH => '/api/user' );
    $req->content_type( 'application/merge-patch+json' );
    $req->content( encode_json({ username => 'johndoe-update-user2' }) );

    my $res = $mech->request($req);
    ok(!$res->is_success, 'not ok to patch username');
    is($res->code, 400, 'response code is Bad Request');
    $mech->get_ok('/api/user', 'retrieve data back' );
    my $data = decode_json($mech->content);
    is($data->{user}{username}, 'johndoe-update-user', 'username was not changed');
};

subtest 'patch role' => sub {
    insert_data();
    my $mech = mech;
    login($mech, 'johndoe-update-user', $Cred{'johndoe-update-user'});

    my $req = HTTP::Request->new( PATCH => '/api/user' );
    $req->content_type( 'application/merge-patch+json' );
    $req->content( encode_json({ role => 'admin' }) );

    my $res = $mech->request($req);
    ok(!$res->is_success, 'not ok to patch role');
    is($res->code, 400, 'response code is Bad Request');
    $mech->get_ok('/api/user', 'retrieve data back' );
    my $data = decode_json($mech->content);
    is($data->{user}{role}, 'author', 'role was not changed');
};

subtest 'patch verified_email' => sub {
    insert_data();
    my $mech = mech;
    login($mech, 'johndoe-update-user', $Cred{'johndoe-update-user'});

    my $req = HTTP::Request->new( PATCH => '/api/user' );
    $req->content_type( 'application/merge-patch+json' );
    $req->content( encode_json({ verified_email => \0 }) );

    my $res = $mech->request($req);
    ok(!$res->is_success, 'not ok to patch verified_email');
    is($res->code, 400, 'response code is Bad Request');
    $mech->get_ok('/api/user', 'retrieve data back' );
    my $data = decode_json($mech->content);
    is($data->{user}{verified_email}, 1, 'verified_email was not changed');
};

subtest 'patch verified_by_peers' => sub {
    insert_data();
    my $mech = mech;
    login($mech, 'johndoe-update-user', $Cred{'johndoe-update-user'});

    my $req = HTTP::Request->new( PATCH => '/api/user' );
    $req->content_type( 'application/merge-patch+json' );
    $req->content( encode_json({ verified_by_peers => \0 }) );

    my $res = $mech->request($req);
    ok(!$res->is_success, 'not ok to patch verified_by_peers');
    is($res->code, 400, 'response code is Bad Request');
    $mech->get_ok('/api/user', 'retrieve data back' );
    my $data = decode_json($mech->content);
    is($data->{user}{verified_by_peers}, 1, 'verified_by_peers was not changed');
};

subtest 'patch email' => sub {
    insert_data();
    my $mech = mech;
    login($mech, 'johndoe-update-user', $Cred{'johndoe-update-user'});

    my $req = HTTP::Request->new( PATCH => '/api/user' );
    $req->content_type( 'application/merge-patch+json' );
    $req->content( encode_json({ email => 'johndoe-update-user-other-email@gmail.com' }) );

    my $res = $mech->request($req);
    ok($res->is_success, 'email changed successfully');
    is($res->code, 204, 'response code is 204 No Content');
    $mech->get_ok('/api/user', 'retrieve data back' );
    my $data = decode_json($mech->content);
    is($data->{user}{verified_email}, 0, 'verified_email was changed');
    is($data->{user}{verified_by_peers}, 1, 'verified_by_peers is still true');
    is($data->{user}{email}, 'johndoe-update-user-other-email@gmail.com', 'email was updated');

    my @inbox = mails->deliveries;
    is(@inbox, 1, 'got 1 email');
    my $email = $inbox[0]{email}->object;
    like($email->body, qr{Hello.*johndoe-update-user}, 'user is greeted by username');
    like($email->body, qr{http://localhost/sign-up/confirm}, 'there is a confirmation link');
    $email->body =~ m{(http://localhost/sign-up/confirm\?[^'"]+)};
    my $confirmation_link = URI->new(decode_entities $1);

    my $token = $confirmation_link->query_param('token');
    my $token_result = schema->resultset('RegistrationToken')->find({ token => $token });
    is($token_result->user->username, 'johndoe-update-user', 'token in the email refers to the correct user');
    is($token_result->user->verified_email, 0, 'user is pending in database');
    is($token_result->voided_at, undef, "the token hasn't been voided");
    isnt($token_result->created_at, undef, "but it has a created_at timestamp");

    # start a new session
    my $mech2 = mech;
    $mech2->get_ok($confirmation_link, 'can click on the confirmation link');
    $mech2->content_like(
        qr/Your account has been verified/,
        'The user has a verified account now'
    );

    $token_result = schema->resultset('RegistrationToken')->find({ token => $token });

    isnt($token_result->voided_at, undef, "the token is now voided");
    is($token_result->user->verified_email, 1, 'user is activated in database');

    # back to original session in $mech
    $mech->get_ok('/api/user', 'retrieve data back again' );
    my $data2 = decode_json($mech->content);
    is($data2->{user}{verified_email}, 1, 'verified_email was changed again');
    is($data2->{user}{verified_by_peers}, 1, 'verified_by_peers is still true');
    is($data2->{user}{email}, 'johndoe-update-user-other-email@gmail.com', 'email was updated');

    mails->clear_deliveries;
};

subtest 'patch name and email' => sub {
    insert_data();
    my $mech = mech;
    login($mech, 'johndoe-update-user', $Cred{'johndoe-update-user'});

    my $req = HTTP::Request->new( PATCH => '/api/user' );
    $req->content_type( 'application/merge-patch+json' );
    $req->content( encode_json({ name => 'John Doe Update User 200', email => 'johndoe-update-user-other-email@gmail.com' }) );

    my $res = $mech->request($req);
    ok($res->is_success, 'request is successful');
    is($res->code, 204, 'response code is 204 No Content');
    $mech->get_ok('/api/user', 'retrieve data back' );
    my $data = decode_json($mech->content);
    is($data->{user}{verified_email}, 0, 'verified_email was changed');
    is($data->{user}{verified_by_peers}, 1, 'verified_by_peers is still true');
    is($data->{user}{email}, 'johndoe-update-user-other-email@gmail.com', 'email was updated');
    is($data->{user}{name}, 'John Doe Update User 200', 'name was updated');

    my @inbox = mails->deliveries;
    is(@inbox, 1, 'got 1 email');
    my $email = $inbox[0]{email}->object;
    like($email->body, qr{Hello.*johndoe-update-user}, 'user is greeted by username');
    like($email->body, qr{http://localhost/sign-up/confirm}, 'there is a confirmation link');
    $email->body =~ m{(http://localhost/sign-up/confirm\?[^'"]+)};
    my $confirmation_link = URI->new(decode_entities $1);

    my $token = $confirmation_link->query_param('token');
    my $token_result = schema->resultset('RegistrationToken')->find({ token => $token });
    is($token_result->user->username, 'johndoe-update-user', 'token in the email refers to the correct user');
    is($token_result->user->verified_email, 0, 'user is pending in database');
    is($token_result->voided_at, undef, "the token hasn't been voided");
    isnt($token_result->created_at, undef, "but it has a created_at timestamp");

    # start a new session
    my $mech2 = mech;
    $mech2->get_ok($confirmation_link, 'can click on the confirmation link');
    $mech2->content_like(
        qr/Your account has been verified/,
        'The user has a verified account now'
    );

    $token_result = schema->resultset('RegistrationToken')->find({ token => $token });

    isnt($token_result->voided_at, undef, "the token is now voided");
    is($token_result->user->verified_email, 1, 'user is activated in database');

    # back to original session in $mech
    $mech->get_ok('/api/user', 'retrieve data back again' );
    my $data2 = decode_json($mech->content);
    is($data2->{user}{verified_email}, 1, 'verified_email was changed again');
    is($data2->{user}{verified_by_peers}, 1, 'verified_by_peers is still true');
    is($data2->{user}{email}, 'johndoe-update-user-other-email@gmail.com', 'email was updated');

    mails->clear_deliveries;
};


subtest 'cant change password via PATCH /api/user' => sub {
    insert_data();
    my $mech = mech;
    login($mech, 'johndoe-update-user', $Cred{'johndoe-update-user'});

    my $new_pass = reverse $Cred{'johndoe-update-user'};

    my $req = HTTP::Request->new( PATCH => '/api/user' );
    $req->content_type( 'application/merge-patch+json' );
    $req->content(
        encode_json({ password => $new_pass })
    );

    my $res = $mech->request($req);
    ok(!$res->is_success, 'not ok to change password this way');
    is($res->code, 400, 'response code is 400 Bad Request');

    my $mech2 = mech;
    cant_login($mech2, 'johndoe-update-user', $new_pass);
};

subtest 'change password' => sub {
    insert_data();
    my $mech = mech;
    login($mech, 'johndoe-update-user', $Cred{'johndoe-update-user'});

    my $new_pass = reverse $Cred{'johndoe-update-user'};

    my $req = HTTP::Request->new( POST => '/api/user/change-password' );
    $req->content_type( 'application/json' );
    $req->content(
        encode_json({
            current_password => $Cred{'johndoe-update-user'},
            new_password     => $new_pass,
            confirm_password => $new_pass
        })
    );

    my $res = $mech->request($req);
    ok($res->is_success, 'ok to change password');
    is($res->code, 204, 'response code is 204 No Content');

    my $mech2 = mech;
    login($mech2, 'johndoe-update-user', $new_pass);
    $mech2->get_ok('/api/user', 'retrieve data back' );
    my $data = decode_json($mech2->content);
    is($data->{user}{username}, 'johndoe-update-user', 'all good after login');
};

done_testing;
