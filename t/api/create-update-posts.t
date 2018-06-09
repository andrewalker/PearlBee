use PearlBee::Test;
use Cpanel::JSON::XS;
use Scalar::Util qw/blessed/;
use utf8;

my $urs = schema->resultset('User');
my $prs = schema->resultset('Post');
my $trs = schema->resultset('PostTag');

sub insert_fixtures {
    $trs->delete;
    $prs->delete;
    $urs->search( { email => 'johndoe-create-post-api@gmail.com' } )->delete;
    my $author1 = $urs->create({
        username          => 'johndoe-create-post-api',
        email             => 'johndoe-create-post-api@gmail.com',
        password          => '6034a0ga6034a0gahe#JTLKJ24HE@jtlkj24',
        name              => 'John Doe Create Post API',
        role              => 'author',
        verified_email    => 1,
        verified_by_peers => 1,
    });
}

# XXX: there's a fair bit of copy paste here, I know.
sub login {
    my ($mech, $author) = @_;

    my %cred = (
        'johndoe-create-post-api' => '6034a0ga6034a0gahe#JTLKJ24HE@jtlkj24',
    );

    $mech->get_ok( '/login', 'Login returns a page' );
    $mech->submit_form_ok(
        {
            with_fields => {
                username => $author,
                password => $cred{$author},
            },
        },
        'Was able to submit form'
    );

    $mech->content_like(
        qr{Welcome.*$author},
        'User is logged in'
    );
}

subtest 'insert new post via POST /api/user/posts' => sub {
    insert_fixtures();
    my $mech = mech;
    login($mech, 'johndoe-create-post-api');

    my $req = HTTP::Request->new( POST => '/api/user/posts' );
    $req->content_type( 'application/json' );
    $req->content(
        encode_json({
            title    => 'Blog post 1',
            slug     => 'blog-post-1',
            abstract => 'Some abstract 1',
            content  => 'Content content content 1',
            status   => 'published',
            tags     => [ qw/whatever foo bar/ ],
            meta     => {
                something_boolean => \1,
                some_string => 'hello',
                some_number => 100,
            },
        })
    );

    my $res = $mech->request($req);
    ok($res->is_success, 'request is successful');
    is($res->code, 201, 'response code is 201 Created');
    my $json_res = decode_json($res->decoded_content);

    is($json_res->{post}{url}, 'http://localhost/johndoe-create-post-api/blog-post-1', 'post url is correct');
    is($json_res->{post}{slug}, 'blog-post-1', 'post slug is correct');
    is($json_res->{post}{title}, 'Blog post 1', 'post title is correct');
    is($json_res->{post}{status}, 'published', 'post status is correct');
    is($json_res->{post}{content}, 'Content content content 1', 'post content is correct');
    is($json_res->{post}{abstract}, 'Some abstract 1', 'post abstract is correct');
    is($json_res->{post}{meta}{something_boolean}, 1, 'something_boolean looks like 1');
    like(
        blessed $json_res->{post}{meta}{something_boolean},
        qr/JSON::PP::Boolean|JSON::XS::Boolean/,
        "it's an actual boolean"
    );
    delete $json_res->{post}{meta}{something_boolean};
    is_deeply($json_res->{post}{meta}, {
        some_string => 'hello',
        some_number => 100,
    }, 'post meta is correct');
    is_deeply($json_res->{post}{tags}, [qw/bar foo whatever/], 'post tags are correct');
    is_deeply(
        $json_res->{post}{author},
        {
            name     => 'John Doe Create Post API',
            username => 'johndoe-create-post-api',
        },
        'post author is correct'
    );
    like($json_res->{post}{created_at}, qr/\d{4}\-\d{2}\-\d{2} \d{1,2}\:\d{2}\:\d{2}(((\+|\-)\d{2})|Z)/, 'created_at is in the correct format');
    like($json_res->{post}{updated_at}, qr/\d{4}\-\d{2}\-\d{2} \d{1,2}\:\d{2}\:\d{2}(((\+|\-)\d{2})|Z)/, 'updated_at is in the correct format');
};

subtest 'insert new post UTF-8' => sub {
    insert_fixtures();
    my $mech = mech;
    login($mech, 'johndoe-create-post-api');

    my $req = HTTP::Request->new( POST => '/api/user/posts' );
    $req->content_type( 'application/json' );
    $req->content(
        encode_json({
            title    => '北亰!!! Really cool UTF-8 stuff.',
            content  => 'Content content content 1',
            status   => 'published',
            tags     => [ qw/t1 t2 t3/ ],
        })
    );

    my $res = $mech->request($req);
    ok($res->is_success, 'request is successful');
    is($res->code, 201, 'response code is 201 Created');
    my $json_res = decode_json($res->decoded_content);

    is($json_res->{post}{url}, 'http://localhost/johndoe-create-post-api/bei-jing-really-cool-utf-8-stuff', 'post url is correct');
    is($json_res->{post}{slug}, 'bei-jing-really-cool-utf-8-stuff', 'post slug is correct');
    is($json_res->{post}{title}, '北亰!!! Really cool UTF-8 stuff.', 'post title is correct');
    is($json_res->{post}{status}, 'published', 'post status is correct');
    is($json_res->{post}{content}, 'Content content content 1', 'post content is correct');
    is($json_res->{post}{abstract}, 'Content content content 1', 'post abstract is correct');
    is_deeply($json_res->{post}{tags}, [qw/t1 t2 t3/], 'post tags are correct');
    is_deeply(
        $json_res->{post}{author},
        {
            name     => 'John Doe Create Post API',
            username => 'johndoe-create-post-api',
        },
        'post author is correct'
    );
    like($json_res->{post}{created_at}, qr/\d{4}\-\d{2}\-\d{2} \d{1,2}\:\d{2}\:\d{2}(((\+|\-)\d{2})|Z)/, 'created_at is in the correct format');
    like($json_res->{post}{updated_at}, qr/\d{4}\-\d{2}\-\d{2} \d{1,2}\:\d{2}\:\d{2}(((\+|\-)\d{2})|Z)/, 'updated_at is in the correct format');
};

done_testing;
