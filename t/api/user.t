use PearlBee::Test;

# Logged in user
# /api/user
# /api/user/posts/:slug
# /api/user/posts?per_page=10
# /api/user/posts?per_page=10&page=2
# /api/user/posts?sort=date&direction=asc
# /api/user/posts?sort=date&direction=desc
# /api/user/posts?since=2018-01-01T10:00:00
# /api/user/posts?filter=foo
# /api/user/posts?tags=foo,bar,baz
#
# Some user specified by username
# /api/user/:user
# /api/user/:user/posts/:slug
# /api/user/:user/posts?per_page=10
# /api/user/:user/posts?per_page=10&page=2
# /api/user/:user/posts?sort=date&direction=asc
# /api/user/:user/posts?sort=date&direction=desc
# /api/user/:user/posts?since=2018-01-01T10:00:00
# /api/user/:user/posts?filter=foo
# /api/user/:user/posts?tags=foo,bar,baz

TODO: {
    local $TODO = 'implement this...';

    subtest 'test /api/user (logged in user)' => sub {
    };

    subtest 'test /api/user/:user (specified user)' => sub {
    };
}

done_testing;
