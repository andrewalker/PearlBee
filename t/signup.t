use PearlBee::Test;
use PearlBee::Helpers::Captcha;

my $user_details = {
    username   => 'johndoe',
    email      => 'johndoe@gmail.com',
    name       => 'John Doe',
    secret     => 'zxcvb',
};

my %expected = (
    username => $user_details->{username},
    email    => $user_details->{email},
    name     => $user_details->{name},
    role     => 'author',
    status   => 'pending',
);

my $urs = schema->resultset('User');

ensure_admin_in_db();

{
    no warnings 'redefine';
    no strict 'refs';

    # The alternative would be trying to mess with the current code in the
    # session, which is even uglier...
    *PearlBee::Helpers::Captcha::new_captcha_code = sub {'zxcvb'};
    *PearlBee::Helpers::Captcha::check_captcha_code
        = sub { $_[0] eq 'zxcvb' };
}

subtest 'successful insert' => sub {
    my $mech = mech;

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;

    $mech->get_ok( '/sign-up', 'Sign-up returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => $user_details,
        },
        'Was able to submit form'
    );

    # If we weren't able to test the successful case, then the tests ensuring we
    # couldn't insert will be useless, so we bail out.
    ok( my $row = $urs->single( { email => 'johndoe@gmail.com' } ),
        'found row in the database' )
        or BAIL_OUT 'Insert is not working, the rest of the tests are irrelevant';

    is( $row->$_, $expected{$_}, "New user's $_ has the expected value" )
        for keys %expected;

    $mech->content_like(
        qr/The user was created and it is waiting for admin approval/,
        'the user is presented with the expected message'
    );

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;
};

subtest 'successful insert, failed e-mail' => sub {
    my $mech = mech;

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;

    $urs->search( { email => 'admin@admin.com' } )
        ->update( { email => 'failme@admin.com' } );

    $mech->get_ok( '/sign-up', 'Sign-up returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => $user_details,
        },
        'Was able to submit form'
    );

    ok( my $row = $urs->single( { email => 'johndoe@gmail.com' } ),
        'found row in the database' );

    is( $row->$_, $expected{$_}, "New user's $_ has the expected value" )
        for keys %expected;

    $mech->content_like( qr/Could not send the email/,
        'the user is presented with the expected message' );

    my $logs = logs;
    like(
        $logs->[0]->{message},
        qr/Could not send the email/,
        'the error is logged'
    );
    is( $logs->[0]->{level}, 'error', "the log level is 'error'" );
    is( scalar @$logs,       1,       'exactly 1 error was logged' );

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;

    $urs->search( { email => 'failme@admin.com' } )
        ->update( { email => 'admin@admin.com' } );
};

subtest 'wrong captcha code' => sub {
    my $mech = mech;

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;

    $mech->get_ok( '/sign-up', 'Sign-up returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                %{$user_details}, secret => '00000',
            },
        },
        'Was able to submit form'
    );

    ok( !defined $urs->single( { email => 'johndoe@gmail.com' } ),
        'row was not found in the database' );

    $mech->content_like( qr/Invalid secret code/,
        'the user is presented with the expected message' );

    my $logs = logs;
    like(
        $logs->[0]->{message},
        qr/Invalid secret code/,
        'the error (Invalid secret code) is logged'
    );
    is( $logs->[0]->{level}, 'error', "the log level is 'error'" );
    is( scalar @$logs,       1,       'exactly 1 error was logged' );

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;
};

subtest 'e-mail already in use' => sub {
    my $mech = mech;

    $urs->search( { username => 'johndoe' } )->delete;
    $urs->search( { username => 'johndoe2' } )->delete;

    $mech->get_ok( '/sign-up', 'Sign-up returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => $user_details,
        },
        'Was able to submit form'
    );

    $mech->get_ok( '/sign-up', 'Sign-up returns a page the second time' );
    $mech->submit_form_ok(
        {
            with_fields => {
                %{$user_details}, username => 'johndoe2',
            },
        },
        'Submit the form a second time'
    );

    ok( !defined $urs->single( { username => 'johndoe2' } ),
        'row was not found in the database' );

    $mech->content_like( qr/Email address already in use/,
        'the user is presented with the expected message' );

    my $logs = logs;
    like(
        $logs->[0]->{message},
        qr/Email address already in use/,
        'the error (Email address already in use) is logged'
    );
    is( $logs->[0]->{level}, 'error', "the log level is 'error'" );
    is( scalar @$logs,       1,       'exactly 1 error was logged' );

    $urs->search( { username => 'johndoe' } )->delete;
    $urs->search( { username => 'johndoe2' } )->delete;
};

subtest 'username already in use' => sub {
    my $mech = mech;

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;
    $urs->search( { email => 'johndoe2@gmail.com' } )->delete;

    $mech->get_ok( '/sign-up', 'Sign-up returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => $user_details,
        },
        'Was able to submit form'
    );

    $mech->get_ok( '/sign-up', 'Sign-up returns a page the second time' );
    $mech->submit_form_ok(
        {
            with_fields => {
                %{$user_details}, email => 'johndoe2@gmail.com',
            },
        },
        'Submit the form a second time'
    );

    ok( !defined $urs->single( { email => 'johndoe2@gmail.com' } ),
        'row was not found in the database' );

    $mech->content_like( qr/Username already in use/,
        'the user is presented with the expected message' );

    my $logs = logs;
    like(
        $logs->[0]->{message},
        qr/Username already in use/,
        'the error (Username already in use) is logged'
    );
    is( $logs->[0]->{level}, 'error', "the log level is 'error'" );
    is( scalar @$logs,       1,       'exactly 1 error was logged' );

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;
    $urs->search( { email => 'johndoe2@gmail.com' } )->delete;
};

subtest 'username empty' => sub {
    my $mech = mech;

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;

    $mech->get_ok( '/sign-up', 'Sign-up returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                %{$user_details}, username => '',
            },
        },
        'Was able to submit form'
    );

    ok( !defined $urs->single( { email => 'johndoe@gmail.com' } ),
        'row was not found in the database' );

    $mech->content_like( qr/Please provide a username/,
        'the user is presented with the expected message' );

    my $logs = logs;
    like(
        $logs->[0]->{message},
        qr/Please provide a username/,
        'the error (Please provide a username) is logged'
    );
    is( $logs->[0]->{level}, 'error', "the log level is 'error'" );
    is( scalar @$logs,       1,       'exactly 1 error was logged' );

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;
};

subtest 'email empty' => sub {
    my $mech = mech;

    $urs->search( { username => 'johndoe' } )->delete;

    $mech->get_ok( '/sign-up', 'Sign-up returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                %{$user_details}, email => '',
            },
        },
        'Was able to submit form'
    );

    ok( !defined $urs->single( { username => 'johndoe' } ),
        'row was not found in the database' );

    $mech->content_like( qr/Please provide an email/,
        'the user is presented with the expected message' );

    my $logs = logs;
    like(
        $logs->[0]->{message},
        qr/Please provide an email/,
        'the error (Please provide an email) is logged'
    );
    is( $logs->[0]->{level}, 'error', "the log level is 'error'" );
    is( scalar @$logs,       1,       'exactly 1 error was logged' );

    $urs->search( { username => 'johndoe' } )->delete;
};

done_testing;
