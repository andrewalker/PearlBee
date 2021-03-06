use PearlBee::Test;
use PearlBee::Helpers::Captcha;
use HTML::Entities qw(decode_entities);
use URI;
use URI::QueryParam;

my $urs = schema->resultset('User');
sub recreate {
    $urs->search( { email => 'johndoe-reset-password@gmail.com' } )->delete;
    $urs->create({
        username => 'johndoe-reset-password',
        email    => 'johndoe-reset-password@gmail.com',
        password => 'type-mane-eng-blake-ripe-marco-kiva-hobby-jason',
        name     => 'John Doe',
        role     => 'author',
        verified_email => 1,
    });
}

{
    no warnings 'redefine';
    no strict 'refs';

    # The alternative would be trying to mess with the current code in the
    # session, which is even uglier...
    *PearlBee::Helpers::Captcha::new_captcha_code = sub {'zxcvb'};
    *PearlBee::Helpers::Captcha::check_captcha_code
        = sub { $_[0] eq 'zxcvb' };
}

# Just to be sure the user is alright, and can login alright. If something
# breaks in the reset password tests, it will be useful to know the results of
# this when debugging.
subtest 'old password works' => sub {
    recreate();
    my $mech = mech;

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => 'johndoe-reset-password@gmail.com',
                password => 'type-mane-eng-blake-ripe-marco-kiva-hobby-jason',
            },
        },
        'Was able to submit form'
    );

    $mech->content_like(
        qr{<h5 class="mt-0">johndoe-reset-password</h5>},
        'User is logged in'
    );

    like($mech->uri->path, qr{^/dashboard}, 'user was redirected to dashboard');

    mails->clear_deliveries;
};

subtest 'reset password with non-existent account' => sub {
    recreate();
    my $mech_trigger = mech;

    $mech_trigger->get_ok( '/login', 'Login returns a page' );
    $mech_trigger->follow_link_ok({ url_regex => qr{/forgot-password\b} }, "there's a link to reset password");

    $mech_trigger->submit_form_ok(
        {
            with_fields => {
                username => 'i-dont-exist@gmail.com',
                secret   => 'zxcvb',
            },
        },
        'was able to submit form to reset password'
    );

    # I considered showing something generic like: "If you have an account, one
    # e-mail was sent". But I think that's not really more secure, only less
    # helpful. The username will be public, because it will be the slug in the
    # URL. And the e-mail won't be public, but all that we would be leaking is
    # whether or not the e-mail has an account on this server. Which could be
    # discovered in a different way (registration). No security advantage at all.
    $mech_trigger->content_like(
        qr{Username or email not found},
        "there's a message about account not found"
    );

    $mech_trigger->content_unlike(
        qr{Check your inbox and follow the steps there to choose a new password},
        "there's no message about email being sent"
    );

    my @inbox = mails->deliveries;
    is(@inbox, 0, 'got no email');

    mails->clear_deliveries;
};

subtest 'reset password with email' => sub {
    recreate();
    test_reset_password_with('johndoe-reset-password@gmail.com');
    mails->clear_deliveries;
};

subtest 'reset password with username' => sub {
    recreate();
    test_reset_password_with('johndoe-reset-password');
    mails->clear_deliveries;
};

sub test_reset_password_with {
    my $username = shift;

    my $mech_trigger = mech;

    $mech_trigger->get_ok( '/login', 'Login returns a page' );
    $mech_trigger->follow_link_ok({ url_regex => qr{/forgot-password\b} }, "there's a link to reset password");

    $mech_trigger->submit_form_ok(
        {
            with_fields => {
                username => $username,
                secret   => 'zxcvb',
            },
        },
        'was able to submit form to reset password'
    );

    $mech_trigger->content_unlike(
        qr{Username or email not found},
        "there's no message about account not found"
    );

    $mech_trigger->content_like(
        qr{Check your inbox and follow the steps there to choose a new password},
        "there's a message about email being sent"
    );

    my @inbox = mails->deliveries;
    is(@inbox, 1, 'got 1 email');
    my $email = $inbox[0]{email}->object;
    like($email->body, qr{Hello.*John Doe}, 'user is greeted by name');
    like($email->body, qr{http://localhost/reset-password}, 'there is a confirmation link');
    $email->body =~ m{(http://localhost/reset-password\?[^'"]+)};
    my $reset_password_link = URI->new(decode_entities $1);

    my $token = $reset_password_link->query_param('token');
    my $token_result = schema->resultset('RegistrationToken')->find({ token => $token });
    is($token_result->user->username, 'johndoe-reset-password', 'token in the email refers to the correct user');
    is($token_result->voided_at, undef, "the token hasn't been voided");
    is($token_result->reason, 'reset-password', "the reason to generate this token is to reset-password");
    isnt($token_result->created_at, undef, "but it has a created_at timestamp");

    # open a new browser session, in a way
    my $mech_reset = mech;
    $mech_reset->get_ok($reset_password_link, 'can follow the reset password link');
    $mech_reset->content_like(qr{New password});

    $mech_reset->submit_form_ok(
        {
            with_fields => {
                password         => 'mane-eng-blake-ripe-marco-kiva-hobby-jason-type',
                confirm_password => 'mane-eng-blake-ripe-marco-kiva-hobby-jason-type',
            },
        },
        'was able to submit form to choose new password'
    );

    $mech_reset->content_like(qr{Your password has been successfully updated});

    note 'trying to login with new password';

    # open a new browser session, again
    my $mech_login = mech;
    $mech_login->get_ok('/login', 'can follow the reset password link');

    $mech_login->submit_form_ok(
        {
            with_fields => {
                username => $username,
                password => 'mane-eng-blake-ripe-marco-kiva-hobby-jason-type',
            },
        },
        'was able to submit form to login'
    );

    $mech_login->content_like(
        qr{<h5 class="mt-0">johndoe-reset-password</h5>},
        'User is logged in'
    );

    note 'trying to login with old password';

    my $mech_old_login = mech;

    $mech_old_login->get_ok( '/login', 'Login returns a page' );
    $mech_old_login->submit_form_ok(
        {
            with_fields => {
                username => $username,
                password => 'type-mane-eng-blake-ripe-marco-kiva-hobby-jason',
            },
        },
        'was able to submit form to login with old password'
    );

    $mech_old_login->content_unlike(
        qr{<h5 class="mt-0">johndoe-reset-password</h5>},
        'User is not logged in'
    );

    $mech_old_login->content_like(
        qr{Invalid login credentials},
        'The message is correct'
    );

    unlike($mech_old_login->uri->path, qr{^/dashboard}, 'user was not redirected to dashboard');
    like($mech_old_login->uri->path, qr{^/login}, 'user is still in login page');
}

$urs->search( { email => 'johndoe-reset-password@gmail.com' } )->delete;

done_testing;
