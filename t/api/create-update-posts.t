use PearlBee::Test;
use Cpanel::JSON::XS;
use Scalar::Util qw/blessed/;
use utf8;

my $urs = schema->resultset('User');
my $prs = schema->resultset('Post');
my $trs = schema->resultset('PostTag');
my $crs = schema->resultset('Comment');

sub insert_fixtures {
    $crs->delete;
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
        qr{<h5 class="mt-0">$author</h5>},
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
    test_post($res->decoded_content, "[reponse to initial post] ");
    my $id = decode_json($res->decoded_content)->{post}{id};

    $urs->single({ username => 'johndoe-create-post-api' })->update({ verified_by_peers => 0 });

    {
        my $res = $mech->request(HTTP::Request->new( GET => '/api/posts/' . $id ));
        ok($res->is_success, '[user requested, verified_by_peers false] request is successful');
        is($res->code, 200, '[user requested, verified_by_peers false] response code is 200 OK');
        test_post($res->decoded_content, "[user requested, verified_by_peers false] ");
    }

    {
        my $mech_anon = mech;

        my $res = $mech_anon->request(HTTP::Request->new( GET => '/api/posts/' . $id ));
        is($res->code, 404, '[anon, verified_by_peers false] response code is 200 OK');
        is_deeply(decode_json($res->decoded_content), { error => 'not found' }, "[anon, verified_by_peers false] post not found");
    }

    $urs->single({ username => 'johndoe-create-post-api' })->update({ verified_by_peers => 1 });

    {
        my $mech_anon = mech;

        my $res = $mech_anon->request(HTTP::Request->new( GET => '/api/posts/' . $id ));
        ok($res->is_success, '[anon, verified_by_peers true] request is successful');
        is($res->code, 200, '[anon, verified_by_peers true] response code is 200 OK');
        test_post($res->decoded_content, '[anon, verified_by_peers true] ');
    }

    sub test_post {
        my ($content, $prefix) = @_;
        my $json_res = decode_json($content);

        is($json_res->{post}{url}, 'http://localhost/johndoe-create-post-api/blog-post-1', $prefix . 'post url is correct');
        is($json_res->{post}{slug}, 'blog-post-1', $prefix . 'post slug is correct');
        is($json_res->{post}{title}, 'Blog post 1', $prefix . 'post title is correct');
        is($json_res->{post}{status}, 'published', $prefix . 'post status is correct');
        is($json_res->{post}{content}, 'Content content content 1', $prefix . 'post content is correct');
        is($json_res->{post}{abstract}, 'Some abstract 1', $prefix . 'post abstract is correct');
        is($json_res->{post}{meta}{something_boolean}, 1, $prefix . 'something_boolean looks like 1');
        like(
            blessed $json_res->{post}{meta}{something_boolean},
            qr/JSON::PP::Boolean|JSON::XS::Boolean/,
            $prefix . "it's an actual boolean"
        );
        delete $json_res->{post}{meta}{something_boolean};
        is_deeply($json_res->{post}{meta}, {
            some_string => 'hello',
            some_number => 100,
        }, $prefix . 'post meta is correct');
        is_deeply($json_res->{post}{tags}, [qw/bar foo whatever/], $prefix . 'post tags are correct');
        is_deeply(
            $json_res->{post}{author},
            {
                name     => 'John Doe Create Post API',
                username => 'johndoe-create-post-api',
            },
            $prefix . 'post author is correct'
        );
        like($json_res->{post}{created_at}, qr/\d{4}\-\d{2}\-\d{2} \d{1,2}\:\d{2}\:\d{2}(((\+|\-)\d{2})|Z)/, $prefix . 'created_at is in the correct format');
        like($json_res->{post}{updated_at}, qr/\d{4}\-\d{2}\-\d{2} \d{1,2}\:\d{2}\:\d{2}(((\+|\-)\d{2})|Z)/, $prefix . 'updated_at is in the correct format');
    }
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

subtest 'update post' => sub {
    insert_fixtures();
    my $mech = mech;
    login($mech, 'johndoe-create-post-api');
    my $id;
    my $last_timestamp;

    {
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
                    foo => 1,
                    bar => 2,
                },
            })
        );

        my $res = $mech->request($req);
        ok($res->is_success, 'request is successful');
        is($res->code, 201, 'response code is 201 Created');
        $id = decode_json($res->decoded_content)->{post}{id};
        $last_timestamp = $prs->find($id)->updated_at;
    }

    {
        my $req = HTTP::Request->new( PATCH => "/api/posts/$id" );
        $req->content_type( 'application/merge-patch+json' );
        $req->content(
            encode_json({
                title    => 'Blog post 2',
            })
        );

        my $res = $mech->request($req);
        is($res->code, 204, 'response code is 204 No Content');
        is($prs->find($id)->title, 'Blog post 2', 'title was changed');
        is($prs->find($id)->slug, 'blog-post-1', 'slug was not changed');
        is_deeply(
            decode_json( $prs->find($id)->meta ),
            { foo => 1, bar => 2 },
            'meta was not changed'
        );
        cmp_ok($prs->find($id)->updated_at, '>', $last_timestamp, 'updated_at was changed');
        $last_timestamp = $prs->find($id)->updated_at;
    }

    {
        my $req = HTTP::Request->new( PATCH => "/api/posts/$id" );
        $req->content_type( 'application/merge-patch+json' );
        $req->content(
            encode_json({
                slug     => 'blog-post-2',
                abstract => 'Some abstract 2',
                content  => 'Content content content 2',
            })
        );

        my $res = $mech->request($req);
        is($res->code, 204, 'response code is 204 No Content');
        is($prs->find($id)->slug, 'blog-post-2', 'slug was changed');
        is($prs->find($id)->abstract, 'Some abstract 2', 'abstract was changed');
        is($prs->find($id)->content, 'Content content content 2', 'content was changed');
        is($prs->find($id)->title, 'Blog post 2', 'title was not changed');
        is_deeply(
            decode_json( $prs->find($id)->meta ),
            { foo => 1, bar => 2 },
            'meta was not changed'
        );
        cmp_ok($prs->find($id)->updated_at, '>', $last_timestamp, 'updated_at was changed');
        $last_timestamp = $prs->find($id)->updated_at;
    }

    {
        my $req = HTTP::Request->new( PATCH => "/api/posts/$id" );
        $req->content_type( 'application/merge-patch+json' );
        $req->content(
            encode_json({
                meta => { baz => 3 }
            })
        );

        my $res = $mech->request($req);
        is($res->code, 204, 'response code is 204 No Content');
        is($prs->find($id)->slug, 'blog-post-2', 'slug was not changed');
        is($prs->find($id)->abstract, 'Some abstract 2', 'abstract was not changed');
        is($prs->find($id)->content, 'Content content content 2', 'content was not changed');
        is($prs->find($id)->title, 'Blog post 2', 'title was not changed');
        is_deeply(
            decode_json( $prs->find($id)->meta ),
            { foo => 1, bar => 2, baz => 3 },
            'meta was correctly changed'
        );
        cmp_ok($prs->find($id)->updated_at, '>', $last_timestamp, 'updated_at was changed');
        $last_timestamp = $prs->find($id)->updated_at;
    }

    {
        my $req = HTTP::Request->new( PATCH => "/api/posts/$id" );
        $req->content_type( 'application/merge-patch+json' );
        $req->content(
            encode_json({
                meta => { bar => undef }
            })
        );

        my $res = $mech->request($req);
        is($res->code, 204, 'response code is 204 No Content');
        is($prs->find($id)->slug, 'blog-post-2', 'slug was not changed');
        is($prs->find($id)->abstract, 'Some abstract 2', 'abstract was not changed');
        is($prs->find($id)->content, 'Content content content 2', 'content was not changed');
        is($prs->find($id)->title, 'Blog post 2', 'title was not changed');
        is_deeply(
            decode_json( $prs->find($id)->meta ),
            { foo => 1, baz => 3 },
            'meta was correctly changed'
        );
        cmp_ok($prs->find($id)->updated_at, '>', $last_timestamp, 'updated_at was changed');
        $last_timestamp = $prs->find($id)->updated_at;
    }
};

done_testing;
