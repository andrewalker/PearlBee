use PearlBee::Test;
use JSON::MaybeXS qw(decode_json);

my $urs = schema->resultset('User');
my $prs = schema->resultset('Post');
my $trs = schema->resultset('PostTag');
my $crs = schema->resultset('Comment');

sub insert_posts {
    $crs->delete;
    $trs->delete;
    $prs->delete;
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
    for my $author ($author1, $author2) {
        my $p1 = $prs->create({
            title    => 'Blog post 1',
            slug     => 'blog-post-1',
            abstract => 'Some abstract 1',
            content  => 'Content content content 1',
            status   => 'published',
            author   => $author,
        });
        $p1->add_to_post_tags({ tag => 't1' });
        $p1->add_to_post_tags({ tag => 't2' });
        $p1->add_to_post_tags({ tag => 't3' });
        $prs->create({
            title    => 'Blog post 2',
            slug     => 'blog-post-2',
            abstract => 'Some abstract 2',
            content  => 'Content content content 2',
            status   => 'published',
            author   => $author,
        });
        $prs->create({
            title    => 'Blog post 3',
            slug     => 'blog-post-3',
            abstract => 'Some abstract 3',
            content  => 'Content content content 3',
            status   => 'draft',
            author   => $author,
        });
        my $p4 = $prs->create({
            title    => 'Blog post 4',
            slug     => 'blog-post-4',
            abstract => 'Some abstract 4',
            content  => 'Content content content 4',
            status   => 'published',
            author   => $author,
        });
        $p4->add_to_post_tags({ tag => 't4' });
        $prs->create({
            title    => 'Blog post 5',
            slug     => 'blog-post-5',
            abstract => 'Some abstract 5',
            content  => 'Content content content 5',
            status   => 'published',
            author   => $author,
        });
        $prs->create({
            title    => 'Some trashy post',
            slug     => 'some-trashy-post',
            abstract => 'Some abstract...',
            content  => 'Content content content...',
            status   => 'trash',
            author   => $author,
        });
    }
}

# Posts by any author
# /api/posts/:id
# /api/posts?per_page=10
# /api/posts?per_page=10&page=2
# /api/posts?sort=date&direction=asc
# /api/posts?sort=date&direction=desc
# /api/posts?since=2018-01-01T10:00:00
# /api/posts?filter=foo
# /api/posts?tags=foo,bar,baz

subtest 'test getting from /api/posts' => sub {
    insert_posts();
    my $mech = mech;

    $mech->get_ok('/api/posts', 'can get /api/posts');
    my $res = decode_json($mech->content);

    test_post($res->{posts}[0], 5, 2);
    test_post($res->{posts}[1], 4, 2, [qw(t4)]);
    test_post($res->{posts}[2], 2, 2);
    test_post($res->{posts}[3], 1, 2, [qw(t1 t2 t3)]);
    test_post($res->{posts}[4], 5, 1);
    test_post($res->{posts}[5], 4, 1, [qw(t4)]);
    test_post($res->{posts}[6], 2, 1);
    test_post($res->{posts}[7], 1, 1, [qw(t1 t2 t3)]);
    is(scalar @{ $res->{posts} }, 8, 'only 8 posts');
};

subtest 'paging' => sub {
    insert_posts();
    my $mech = mech;

    $mech->get_ok('/api/posts?per_page=3', 'can get /api/posts?per_page=3');
    my $res1 = decode_json($mech->content);

    test_post($res1->{posts}[0], 5, 2);
    test_post($res1->{posts}[1], 4, 2, [qw(t4)]);
    test_post($res1->{posts}[2], 2, 2);
    is(scalar @{ $res1->{posts} }, 3, 'only 3 posts in this page');

    $mech->get_ok('/api/posts?per_page=3&page=2', 'can get /api/posts?per_page=3&page=2');
    my $res2 = decode_json($mech->content);

    test_post($res2->{posts}[0], 1, 2, [qw(t1 t2 t3)]);
    test_post($res2->{posts}[1], 5, 1);
    test_post($res2->{posts}[2], 4, 1, [qw(t4)]);
    is(scalar @{ $res2->{posts} }, 3, 'only 3 posts in this page');

    $mech->get_ok('/api/posts?per_page=3&page=3', 'can get /api/posts?per_page=3&page=2');
    my $res3 = decode_json($mech->content);
    test_post($res3->{posts}[0], 2, 1);
    test_post($res3->{posts}[1], 1, 1, [qw(t1 t2 t3)]);
    is(scalar @{ $res3->{posts} }, 2, 'only 2 posts in this page');
};

subtest 'by tags' => sub {
    insert_posts();
    my $mech = mech;

    $mech->get_ok('/api/posts?tags=t1,t4', 'can get /api/posts?tags=t1,t4');
    my $res1 = decode_json($mech->content);

    test_post($res1->{posts}[0], 4, 2, [qw(t4)]);
    test_post($res1->{posts}[1], 1, 2, [qw(t1 t2 t3)]);
    test_post($res1->{posts}[2], 4, 1, [qw(t4)]);
    test_post($res1->{posts}[3], 1, 1, [qw(t1 t2 t3)]);
    is(scalar @{ $res1->{posts} }, 4, 'only 4 posts in this page');

    $mech->get_ok('/api/posts?tags=t2,t3', 'can get /api/posts?tags=t2,t3');
    my $res2 = decode_json($mech->content);

    test_post($res2->{posts}[0], 1, 2, [qw(t1 t2 t3)]);
    test_post($res2->{posts}[1], 1, 1, [qw(t1 t2 t3)]);
    is(scalar @{ $res2->{posts} }, 2, 'only 2 posts in this page');
};

subtest 'sorting created_at desc (default)' => sub {
    insert_posts();
    my $mech = mech;

    $mech->get_ok('/api/posts?sort=created_at&direction=desc', 'can get /api/posts?sort=created_at&direction=desc');
    my $res = decode_json($mech->content);

    test_post($res->{posts}[0], 5, 2);
    test_post($res->{posts}[1], 4, 2, [qw(t4)]);
    test_post($res->{posts}[2], 2, 2);
    test_post($res->{posts}[3], 1, 2, [qw(t1 t2 t3)]);
    test_post($res->{posts}[4], 5, 1);
    test_post($res->{posts}[5], 4, 1, [qw(t4)]);
    test_post($res->{posts}[6], 2, 1);
    test_post($res->{posts}[7], 1, 1, [qw(t1 t2 t3)]);
    is(scalar @{ $res->{posts} }, 8, 'only 8 posts');
};

subtest 'sorting created_at asc' => sub {
    insert_posts();
    my $mech = mech;

    $mech->get_ok('/api/posts?sort=created_at&direction=asc', 'can get /api/posts?sort=created_at&direction=desc');
    my $res = decode_json($mech->content);

    test_post($res->{posts}[7], 5, 2);
    test_post($res->{posts}[6], 4, 2, [qw(t4)]);
    test_post($res->{posts}[5], 2, 2);
    test_post($res->{posts}[4], 1, 2, [qw(t1 t2 t3)]);
    test_post($res->{posts}[3], 5, 1);
    test_post($res->{posts}[2], 4, 1, [qw(t4)]);
    test_post($res->{posts}[1], 2, 1);
    test_post($res->{posts}[0], 1, 1, [qw(t1 t2 t3)]);
    is(scalar @{ $res->{posts} }, 8, 'only 8 posts');
};

subtest 'filtering' => sub {
    insert_posts();
    my $mech = mech;

    $mech->get_ok('/api/posts?filter=post%205', 'can get /api/posts?filter=post%205');
    my $res = decode_json($mech->content);

    test_post($res->{posts}[0], 5, 2);
    test_post($res->{posts}[1], 5, 1);
    is(scalar @{ $res->{posts} }, 2, 'only 2 posts');
};

sub test_post {
    my ($got, $exp_p, $exp_a, $tags) = @_;

    ok($got->{id}, 'Post has an id');
    ok($got->{created_at}, 'Post has a created_at');
    ok($got->{updated_at}, 'Post has an updated_at');
    is($got->{created_at}, $got->{updated_at}, 'Create and update dates are equal');
    is($got->{title}, "Blog post $exp_p", 'Post title is expected');
    is($got->{slug}, "blog-post-$exp_p", 'Post slug is expected');
    is($got->{url}, "http://localhost/johndoe-author$exp_a/blog-post-$exp_p", 'Post url is expected');
    is($got->{abstract}, "Some abstract $exp_p", 'Post abstract is expected');
    is_deeply($got->{author}, {
        username => "johndoe-author$exp_a",
        name     => "John Doe Author $exp_a",
    }, 'Post author is expected');
    is_deeply($got->{tags}, $tags || [], 'Post tags are expected');
}

done_testing;
