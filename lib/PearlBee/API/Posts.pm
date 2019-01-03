package PearlBee::API::Posts;

# ABSTRACT: Posts-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Tiny;

use PearlBee::Helpers::SendAs;
use PearlBee::Model::Posts;

my $model = PearlBee::Model::Posts->new(
    user_rs     => resultset('User'),
    post_rs     => resultset('Post'),
    post_tag_rs => resultset('PostTag'),
    uri_for     => \&uri_for,
);

get '/api/posts' => sub {
    return api_posts_endpoint();
};

get '/api/user/:user/posts' => sub {
    my $username = route_parameters->{'user'};

    my $author_obj = resultset('User')->search(
        { username => $username },
        { columns => 'id' }
    )->first;

    if (!$author_obj) {
        status 'not_found';
        send_as JSON => { error => "not found" };
    }

    return api_posts_endpoint($author_obj->id);
};

get '/api/user/posts' => sub {
    return api_posts_endpoint(session 'user_id');
};

get '/api/posts/:id' => sub {
    my $post_id = route_parameters->{'id'};

    my ($public_post) = $model->search_posts({
        id => $post_id,
    });

    $public_post and
        return send_as JSON => { post => $public_post };

    if (my $user = session 'user_id') {
        my ($private_post) = $model->search_posts({
            id             => $post_id,
            author         => $user,
            only_published => 0,
        });

        $private_post and
            return send_as JSON => { post => $private_post };
    }

    status 'not_found';
    send_as JSON => { error => "not found" };
};

#POST /api/user/posts
#{
#    "title": "...",
#    "slug": "optional",
#    "abstract": "optional",
#    "content": "...",
#    "meta": {
#        "key1": "value1",
#        "key2": "value2",
#        "key3": "value3"
#    },
#    "tags": [ "tag1", "tag2", "tag3" ]
#}

post '/api/user/posts' => needs login => sub {
    if (request->header('Content-Type') ne 'application/json') {
        status 'not_acceptable';
        send_as JSON => {
            error => 'Not acceptable. Use application/json.'
        };
    }

    my $user_id = session 'user_id';
    my $json    = decode_json( request->body );

    my ($post, $error) = $model->create_post($user_id, $json);

    for ( $error || () ) {
        /^user-not-found$/
            and return send_as_bad_request({ error => q/invalid user_id in session/ });
        /^meta-not-json-object$/
            and return send_as_bad_request({ error => q/meta has to be a JSON object/ });
        /^meta-deep$/
            and return send_as_bad_request({ error => q/meta can't have deep data structures/ });
        /^meta-too-big$/
            and return send_as_bad_request({ error => q/meta is too big/ });
        /^tags-not-string-array$/
            and return send_as_bad_request({ error => q/tags are supposed to be an array of strings/ });
        /^tags-too-big$/
            and return send_as_bad_request({ error => q/tags are too big/ });
        /^abstract-too-big$/
            and return send_as_bad_request({ error => q/abstract is too big/ });
        /^post-not-created$/
            and return send_as_bad_request({ error => q/unknown error creating post/ });

        return send_as_bad_request({ error => q/unknown error creating post/ });
    }

    status 'created';
    send_as JSON => {
        post => $model->search_posts({ id => $post->id, published_only => 0 }),
    };
};

patch '/api/posts/:id' => needs 'login' => sub {
    if (request->header('Content-Type') ne 'application/merge-patch+json') {
        status 'not_acceptable';
        return send_as JSON => {
            error => 'Not acceptable. Use application/merge-patch+json, according to RFC 7396'
        };
    }

    my $user_id = session 'user_id';
    my $post_id = route_parameters->{id};
    my $json    = decode_json( request->body );

    my ($post, $error) = $model->update_post($user_id, $post_id, $json);

    for ( $error || () ) {
        if (/^post-not-found$/) {
            status 'not_found';
            return send_as JSON => { error => 'not found' };
        }
        if (/^forbidden$/) {
            status 'forbidden';
            return send_as JSON => { error => "You can't edit this post." };
        }
        /^meta-not-json-object$/
            and return send_as_bad_request({ error => q/meta has to be a JSON object/ });
        /^meta-deep$/
            and return send_as_bad_request({ error => q/meta can't have deep data structures/ });
        /^meta-too-big$/
            and return send_as_bad_request({ error => q/meta is too big/ });
        /^tags-not-string-array$/
            and return send_as_bad_request({ error => q/tags are supposed to be an array of strings/ });
        /^tags-too-big$/
            and return send_as_bad_request({ error => q/tags are too big/ });
        /^abstract-too-big$/
            and return send_as_bad_request({ error => q/abstract is too big/ });
        /^nothing-to-update$/
            and return send_as_bad_request({ error => q/nothing was updated/ });
    }

    status 'no_content';
    return '';
};

# Search

my %sort = map +($_, $_), qw( id created_at updated_at );
my %dir  = map +($_, "-$_"), qw( asc desc );

sub api_posts_endpoint {
    my ($author) = @_;
    my $per_page  = int(query_parameters->{'per_page'} // 0) || 10;
    my $page      = int(query_parameters->{'page'}     // 0) || 1;
    my $sort      = $sort{ query_parameters->{'sort'}      || 'created_at' } || 'created_at';
    my $direction = $dir{  query_parameters->{'direction'} || 'desc' }       || '-desc';

    if ($per_page > 50) {
        $per_page = 50;
    }

    my @posts = $model->search_posts({
        author    => $author,
        per_page  => $per_page,
        page      => $page,
        sort      => $sort,
        direction => $direction,
        tags      => query_parameters->{'tags'},
        filter    => query_parameters->{'filter'},
    });

    send_as JSON => { posts => \@posts, };
}

1;
