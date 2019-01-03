use PearlBee::Test;
use JSON::MaybeXS qw(decode_json encode_json);

my $urs = schema->resultset('User');
my $prs = schema->resultset('Post');
my $trs = schema->resultset('PostTag');
my $crs = schema->resultset('Comment');
my ($post1, $post2, $post_trash);

sub insert_posts {
    $crs->delete_all;
    $trs->delete_all;
    $prs->delete_all;
    $urs->search( { email => 'johndoe-author1@gmail.com' } )->delete;
    $urs->search( { email => 'johndoe-author2@gmail.com' } )->delete;

    my $author1 = $urs->create({
        username          => 'johndoe-author1',
        email             => 'johndoe-author1@gmail.com',
        password          => 'type-mane-eng-kiva-hobby-jason-blake-ripe-marco',
        name              => 'John Doe Author 1',
        role              => 'author',
        verified_email    => 1,
        verified_by_peers => 1,
    });
    my $author2 = $urs->create({
        username          => 'johndoe-author2',
        email             => 'johndoe-author2@gmail.com',
        password          => 'kiva-type-mane-eng-hobby-jason-blake-ripe-marco',
        name              => 'John Doe Author 2',
        role              => 'author',
        verified_email    => 1,
        verified_by_peers => 1,
    });

    $post1 = $prs->create({
        title    => 'Blog post 1',
        slug     => 'blog-post-1',
        abstract => 'Some abstract 1',
        content  => 'Content content content 1',
        status   => 'published',
        author   => $author1,
    });
    $post2 = $prs->create({
        title    => 'Blog post 2',
        slug     => 'blog-post-2',
        abstract => 'Some abstract 2',
        content  => 'Content content content 1',
        status   => 'published',
        author   => $author2,
    });
    $post_trash = $prs->create({
        title    => 'Some trashy post',
        slug     => 'some-trashy-post',
        abstract => 'Some abstract...',
        content  => 'Content content content...',
        status   => 'trash',
        author   => $author1,
    });
}

sub login {
    my ($mech, $author) = @_;

    my %cred = (
        'johndoe-author1' => 'type-mane-eng-kiva-hobby-jason-blake-ripe-marco',
        'johndoe-author2' => 'kiva-type-mane-eng-hobby-jason-blake-ripe-marco',
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

subtest 'get empty comments' => sub {
    insert_posts();
    my $mech = mech;

    $mech->get_ok('/api/posts/' . $post1->id . '/comments', 'can get comments by post id');
    my $res = decode_json($mech->content);

    is_deeply($res->{comments}, [], 'no comments returned');
};

subtest 'insert one comment' => sub {
    insert_posts();
    my $mech = mech;
    login($mech, 'johndoe-author2');

    my $req = HTTP::Request->new( POST => '/api/posts/' . $post1->id . '/comments' );
    $req->content_type( 'application/json' );
    $req->content( encode_json({ content  => 'Content content content 1' }) );

    my $res = $mech->request($req);
    ok($res->is_success, 'request is successful');
    is($res->code, 201, 'response code is 201 Created');

    $mech->get_ok('/api/posts/' . $post1->id . '/comments', 'can get comments by post id');
    my $res2 = decode_json($mech->content);
    my $c = $res2->{comments}->[0];

    is(
        $c->{content},
        'Content content content 1',
        'content is correct'
    );
    is(
        $c->{status},
        'published',
        'status is correct'
    );
    like(
        $c->{created_at},
        qr[\d{4}-\d{2}-\d{2}.\d{2}:\d{2}:\d{2}],
        'created_at looks like a date'
    );

    ok($c->{post}{id}, 'Comment post has an id');
    is($c->{post}{title}, "Blog post 1", 'Comment post title is expected');
    is($c->{post}{slug}, "blog-post-1", 'Comment post slug is expected');
    is($c->{post}{url}, "http://localhost/johndoe-author1/blog-post-1", 'Comment post url is expected');

    is_deeply(
        $c->{author},
        {
            name     => "John Doe Author 2",
            username => "johndoe-author2",
        },
        'comment author is correct'
    );

    my $mech2 = mech;
    $mech2->get_ok('/api/posts/' . $post1->id . '/comments', 'can get comments by post id');
    is(decode_json($mech2->content)->{comments}[0]{id}, $c->{id}, 'results from unlogged user are similar');
};

subtest 'insert one comment' => sub {
    insert_posts();
    my $mech = mech;
    login($mech, 'johndoe-author2');

    my $req = HTTP::Request->new( POST => '/api/posts/' . $post1->id . '/comments' );
    $req->content_type( 'application/json' );
    $req->content( encode_json({ content  => 'Content content content 1' }) );

    my $res = $mech->request($req);
    ok($res->is_success, 'request is successful');
    is($res->code, 201, 'response code is 201 Created');

    $mech->get_ok('/api/posts/' . $post1->id . '/comments', 'can get comments by post id');
    my $res2 = decode_json($mech->content);
    my $c = $res2->{comments}->[0];

    is(
        $c->{content},
        'Content content content 1',
        'content is correct'
    );
    is(
        $c->{status},
        'published',
        'status is correct'
    );
    like(
        $c->{created_at},
        qr[\d{4}-\d{2}-\d{2}.\d{2}:\d{2}:\d{2}],
        'created_at looks like a date'
    );

    ok($c->{post}{id}, 'Comment post has an id');
    is($c->{post}{title}, "Blog post 1", 'Comment post title is expected');
    is($c->{post}{slug}, "blog-post-1", 'Comment post slug is expected');
    is($c->{post}{url}, "http://localhost/johndoe-author1/blog-post-1", 'Comment post url is expected');

    is_deeply(
        $c->{author},
        {
            name     => "John Doe Author 2",
            username => "johndoe-author2",
        },
        'comment author is correct'
    );

    {
        my $mech = mech;
        $mech->get_ok('/api/posts/' . $post1->id . '/comments', 'can get comments by post id');
        is(decode_json($mech->content)->{comments}[0]{id}, $c->{id}, 'results from unlogged user are similar');
    }

    # delete unauthorized
    {
        my $req = HTTP::Request->new( DELETE => '/api/comments/' . $c->{id} );
        is( mech->request($req)->code, 401, 'delete request is not authorized' );
        my $mech = mech;
        login($mech, 'johndoe-author1');
        is( $mech->request($req)->code, 403, 'delete by author1 is forbidden' );
        $mech->get_ok('/api/posts/' . $post1->id . '/comments', 'can get comments by post id');
        is(decode_json($mech->content)->{comments}[0]{id}, $c->{id}, 'comment is still there');
    }

    # delete
    {
        my $req = HTTP::Request->new( DELETE => '/api/comments/' . $c->{id} );
        my $res = $mech->request($req);
        is( $res->code, 204, 'delete request is successful' );
    }

    {
        my $mech = mech;

        $mech->get_ok('/api/posts/' . $post1->id . '/comments', 'can get comments by post id');
        my $res = decode_json($mech->content);

        is_deeply($res->{comments}, [], 'no comments returned');
    }
};

done_testing;
