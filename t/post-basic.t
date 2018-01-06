use PearlBee::Test;
use PearlBee::Helpers::Captcha;

my $urs = schema->resultset('User');
sub recreate {
    $urs->search( { email => 'johndoe-post-basic@gmail.com' } )->delete;
    $urs->create({
        username => 'johndoe-post-basic',
        email    => 'johndoe-post-basic@gmail.com',
        password => 'type-mane-eng-kiva-hobby-jason-blake-ripe-marco',
        name     => 'John Doe',
        role     => 'author',
        status   => 'activated',
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

recreate();

subtest 'login' => sub {
    my $mech = mech;

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => 'johndoe-post-basic',
                password => 'type-mane-eng-kiva-hobby-jason-blake-ripe-marco',
            },
        },
        'Was able to submit form'
    );

    $mech->content_like(
        qr{Welcome.*johndoe-post-basic},
        'User is logged in'
    );

    like($mech->uri->path, qr{^/dashboard}, 'user was redirected to dashboard');
    $mech->follow_link_ok({ url_regex => qr{dashboard/posts/new} }, "can follow link to create post");
};

done_testing;
