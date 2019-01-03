package PearlBee::API::Comments;

# ABSTRACT: Comments-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use PearlBee::Helpers::SendAs;

get '/api/posts/:id/comments' => sub {
    my $post_id = route_parameters->{'id'};

    my $post = get_post($post_id);

    if (!$post) {
        status 'not_found';
        send_as JSON => { error => "not found" };
    }

    my @comments = map {
        $_->{post}{url} = uri_for('/' . $_->{author_2}{username} . '/' . $_->{post}{slug});
        delete $_->{author_2};
        $_
    } $post->comments->search(
        { 'me.status' => { '!=', 'trash' } },
        {
            join         => [ 'author', { 'post' => 'author' } ],
            order_by     => { -desc => 'created_at' },
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            '+select'    => [
                'author.username', 'author.name',
                'post.slug',       'post.title',
                'post.id',         'author_2.username'
            ],
        },
    )->all;

    send_as JSON => { comments => \@comments };
};

post '/api/posts/:id/comments' => sub {
    if (request->header('Content-Type') ne 'application/json') {
        status 'not_acceptable';
        send_as JSON => {
            error => 'Not acceptable. Use application/json.'
        };
    }

    my $user_id = session 'user_id';
    my $post_id = route_parameters->{'id'};
    my $json    = decode_json( request->body );

    my ($comment, $error) = create_comment($user_id, $post_id, $json);

    for ( $error || () ) {
        /^user-not-found$/
            and return send_as_bad_request({ error => q/invalid user_id in session/ });
        /^post-not-found$/
            and return send_as_bad_request({ error => q/invalid post id/ });
        /^comment-not-created$/
            and return send_as_bad_request({ error => q/unknown error creating comment/ });

        return send_as_bad_request({ error => q/unknown error creating comment/ });
    }

    status 'created';
    send_as JSON => {
        comment => map {
            $_->{post}{url} = uri_for('/' . $_->{author_2}{username} . '/' . $_->{post}{slug});
            delete $_->{author_2};
            $_
        } resultset('Comment')->search(
            { 'me.id' => $comment->id },
            {
                join         => [ 'author', { 'post' => 'author' } ],
                order_by     => { -desc => 'created_at' },
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                '+select'    => [
                    'author.username', 'author.name',
                    'post.slug',       'post.title',
                    'post.id',         'author_2.username'
                ],
            },
        )->single
    };
};

del '/api/comments/:id' => sub {
    my $user_id = session 'user_id'
        or return send_as_unauthorized({ error => 'unauthorized' });
    my $comment_id = route_parameters->{'id'};

    my $comment = resultset('Comment')->find($comment_id)
        or return send_as_not_found({ error => 'comment not found' });

    if ($comment->get_column('author') != $user_id) {
        return send_as_forbidden({ error => "you don't have permission to delete this comment" });
    }

    $comment->update({ status => 'trash' });

    status 'no_content';
};

sub get_post {
    my ($post_id) = @_;

    my $post = resultset('Post')->search(
        {
            'me.id'                    => $post_id,
            'me.status'                => 'published',
            'author.verified_by_peers' => 1
        },
        { join => 'author' }
    )->single;

    return $post if $post;

    if (my $user_id = session 'user_id') {
        my $private_post = resultset('Post')->search({
            'id'     => $post_id,
            'author' => $user_id,
            'status' => { '!=', 'trash' },
        })->single;

        return $private_post if $private_post;
    }
}

sub create_comment {
    my ($user_id, $post_id, $data) = @_;

    my $user = resultset('User')->find($user_id)
        or return (undef, 'user-not-found');

    my $post = get_post($post_id)
        or return (undef, 'post-not-found');

    my $comment = $post->add_to_comments({
        author   => $user,
        content  => $data->{content},
    });

    $comment
        or return (undef, 'comment-not-created');

    return ($comment, undef);
}

1;
