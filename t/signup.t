use PearlBee::Test;
use PearlBee::Helpers::Captcha;
use HTML::Entities qw(decode_entities);
use URI;
use URI::QueryParam;

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
        qr/Please check your inbox and confirm your email address/,
        'the user is presented with the expected message'
    );

    my @inbox = mails->deliveries;
    is(@inbox, 1, 'got 1 email');
    my $email = $inbox[0]{email}->object;
    like($email->body, qr{Hello.*John Doe}, 'user is greeted by name');
    like($email->body, qr{http://localhost/sign-up/confirm}, 'there is a confirmation link');
    $email->body =~ m{(http://localhost/sign-up/confirm\?[^'"]+)};
    my $confirmation_link = URI->new(decode_entities $1);

    my $token = $confirmation_link->query_param('token');
    my $token_result = schema->resultset('RegistrationToken')->find({ token => $token });
    is($token_result->user->username, 'johndoe', 'token in the email refers to the correct user');
    is($token_result->user->status, 'pending', 'user is pending in database');
    is($token_result->voided_at, undef, "the token hasn't been voided");
    isnt($token_result->created_at, undef, "but it has a created_at timestamp");

    $mech->get_ok($confirmation_link, 'can click on the confirmation link');
    $mech->content_like(
        qr/Your account has been verified/,
        'The user has a verified account now'
    );

    $token_result = schema->resultset('RegistrationToken')->find({ token => $token });

    isnt($token_result->voided_at, undef, "the token is now voided");
    is($token_result->user->status, 'activated', 'user is activated in database');

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;
    mails->clear_deliveries;
};

subtest 'successful insert, failed e-mail' => sub {
    my $mech = mech;

    $urs->search( { email => 'johndoe@gmail.com' } )->delete;
    $urs->search( { email => 'failme@gmail.com' } )->delete;

    $mech->get_ok( '/sign-up', 'Sign-up returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => { %$user_details, email => 'failme@gmail.com' },
        },
        'Was able to submit form'
    );

    ok( my $row = $urs->single( { email => 'failme@gmail.com' } ),
        'found row in the database' );

    # email is different than what's in %expected in this case, and we know
    # it's correct because we found the row using the email
    is( $row->$_, $expected{$_}, "New user's $_ has the expected value" )
        for grep !/^email$/, keys %expected;

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

    $urs->search( { email => 'failme@gmail.com' } )->delete;
    mails->clear_deliveries;
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
    mails->clear_deliveries;
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
    mails->clear_deliveries;
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
    mails->clear_deliveries;
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
    mails->clear_deliveries;
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
    mails->clear_deliveries;
};

done_testing;
