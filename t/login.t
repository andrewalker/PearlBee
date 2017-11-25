use PearlBee::Test;

my $urs = schema->resultset('User');
$urs->search( { email => 'johndoe-login@gmail.com' } )->delete;
$urs->create({
    username => 'johndoe-login',
    email    => 'johndoe-login@gmail.com',
    password => 'type-mane-eng-blake-ripe-marco-kiva-hobby-jason',
    name     => 'John Doe',
    role     => 'author',
    status   => 'activated',
});

subtest 'successful login (email / password)' => sub {
    my $mech = mech;

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => 'johndoe-login@gmail.com',
                password => 'type-mane-eng-blake-ripe-marco-kiva-hobby-jason',
            },
        },
        'Was able to submit form'
    );

    $mech->content_like(
        qr{Welcome.*johndoe-login},
        'User is logged in'
    );

    like($mech->uri->path, qr{^/dashboard}, 'user was redirected to dashboard');
};

subtest 'successful login (username / password)' => sub {
    my $mech = mech;

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => 'johndoe-login',
                password => 'type-mane-eng-blake-ripe-marco-kiva-hobby-jason',
            },
        },
        'Was able to submit form'
    );

    $mech->content_like(
        qr{Welcome.*johndoe-login},
        'User is logged in'
    );

    like($mech->uri->path, qr{^/dashboard}, 'user was redirected to dashboard');
};

subtest 'invalid login: username doesn\'t exist' => sub {
    my $mech = mech;

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => 'johndoe-lo',
                password => 'type-mane-eng-blake-ripe-marco-kiva-hobby-jason',
            },
        },
        'Was able to submit form'
    );

    $mech->content_unlike(
        qr{Welcome.*johndoe-login},
        'User is not logged in'
    );

    $mech->content_like(
        qr{Invalid login credentials},
        'The message is correct'
    );

    unlike($mech->uri->path, qr{^/dashboard}, 'user was not redirected to dashboard');
    like($mech->uri->path, qr{^/login}, 'user is still in login page');
};

subtest 'invalid login: email doesn\'t exist' => sub {
    my $mech = mech;

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => 'johndoe-login@gmail.co',
                password => 'type-mane-eng-blake-ripe-marco-kiva-hobby-jason',
            },
        },
        'Was able to submit form'
    );

    $mech->content_unlike(
        qr{Welcome.*johndoe-login},
        'User is not logged in'
    );

    $mech->content_like(
        qr{Invalid login credentials},
        'The message is correct'
    );

    unlike($mech->uri->path, qr{^/dashboard}, 'user was not redirected to dashboard');
    like($mech->uri->path, qr{^/login}, 'user is still in login page');
};

subtest 'invalid login: invalid password' => sub {
    my $mech = mech;

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => 'johndoe-login@gmail.com',
                password => 'type-mane-eng-blake-ripe-marco-kiva-hobby-jason-2',
            },
        },
        'Was able to submit form'
    );

    $mech->content_unlike(
        qr{Welcome.*johndoe-login},
        'User is not logged in'
    );

    $mech->content_like(
        qr{Invalid login credentials},
        'The message is correct'
    );

    unlike($mech->uri->path, qr{^/dashboard}, 'user was not redirected to dashboard');
    like($mech->uri->path, qr{^/login}, 'user is still in login page');
};

subtest 'invalid login: suspended user' => sub {
    my $mech = mech;

    $urs->find({ email => 'johndoe-login@gmail.com' })->update({ status => 'suspended' });

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => 'johndoe-login@gmail.com',
                password => 'type-mane-eng-blake-ripe-marco-kiva-hobby-jason',
            },
        },
        'Was able to submit form'
    );

    $mech->content_unlike(
        qr{Welcome.*johndoe-login},
        'User is not logged in'
    );

    $mech->content_like(
        qr{Your account has been suspended},
        'The message is correct'
    );

    unlike($mech->uri->path, qr{^/dashboard}, 'user was not redirected to dashboard');
    like($mech->uri->path, qr{^/login}, 'user is still in login page');
};

subtest 'invalid login: pending user' => sub {
    my $mech = mech;

    $urs->find({ email => 'johndoe-login@gmail.com' })->update({ status => 'pending' });

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => 'johndoe-login@gmail.com',
                password => 'type-mane-eng-blake-ripe-marco-kiva-hobby-jason',
            },
        },
        'Was able to submit form'
    );

    $mech->content_unlike(
        qr{Welcome.*johndoe-login},
        'User is not logged in'
    );

    $mech->content_like(
        qr{Your e-mail address has not been verified yet},
        'The message is correct'
    );

    unlike($mech->uri->path, qr{^/dashboard}, 'user was not redirected to dashboard');
    like($mech->uri->path, qr{^/login}, 'user is still in login page');
};

$urs->search( { email => 'johndoe-login@gmail.com' } )->delete;

done_testing;
