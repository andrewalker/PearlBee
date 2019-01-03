package PearlBee::Comments;
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Tiny;

post '/comments' => needs 'login' => sub {
    my $user_id = session 'user_id';
    my $post_id = body_parameters->{'post_id'};
    my $content = body_parameters->{'content'};

    my ($comment, $error) = create_comment($user_id, $post_id, { content => $content });

    # TODO: deal with errors

    redirect request->referer;
};

get '/delete_comment/:id' => needs 'login' => sub {
    my $user_id = session 'user_id';
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
