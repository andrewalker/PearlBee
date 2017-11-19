package PearlBee::Comments::Builtin::AddComment;
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Mailer::PearlBee;
use PearlBee::Helpers::Captcha;

post '/comment/add' => sub {
    my $parameters = body_parameters;
    my $fullname   = $parameters->{'fullname'};
    my $post_id    = $parameters->{'id'};
    my $secret     = $parameters->{'secret'};
    my @comments
        = resultset('Comment')
        ->search(
        { post_id => $post_id, status => 'approved', reply_to => undef } );
    my $post       = resultset('Post')->find($post_id);
    my @categories = resultset('Category')->all();
    my @recent     = resultset('Post')->search( { status => 'published' },
        { order_by => { -desc => "created_date" }, rows => 3 } );
    my @popular
        = resultset('View::PopularPosts')->search( {}, { rows => 3 } );
    my $user = session('user');

    ( $parameters->{'reply_to'} ) = $parameters->{'in_reply_to'} =~ /(\d+)/g;
    if ( $parameters->{'reply_to'} ) {
        my $comm = resultset('Comment')
            ->find( { id => $parameters->{'reply_to'} } );
        if ($comm) {
            $parameters->{'reply_to_content'} = $comm->content;
            $parameters->{'reply_to_user'}    = $comm->fullname;
        }
    }

    my $template_params = {
        post       => $post,
        categories => \@categories,
        popular    => \@popular,
        recent     => \@recent,
        warning    => 'The secret code is incorrect'
    };

    if ( PearlBee::Helpers::Captcha::check_captcha_code($secret) ) {

        # If the person who leaves the comment is either the author or the admin the comment is automaticaly approved
        my $comment
            = resultset('Comment')->can_create( $parameters, $user );

        # Notify the author that a new comment was submited
        my $author = $post->user;

        eval {
            sendmail({
                template_file => 'new_comment.tt',
                name          => $author->first_name,
                email_address => $author->email,
                subject => (
                    $parameters->{'reply_to'}
                    ? 'A comment reply was submitted to your post'
                    : 'A new comment was submitted to your post'
                ),
                variables => {
                    fullname  => $fullname,
                    title     => $post->title,
                    comment   => $parameters->{'comment'},
                    signature => '',
                    post_url  => config->{app_url}
                        . '/post/'
                        . $post->slug,
                    app_url          => config->{app_url},
                    reply_to_content => $parameters->{'reply_to_content'}
                        || '',
                    reply_to_user => $parameters->{'reply_to_user'} || '',
                }
            });
            1;
        } or do {
            error 'Could not send the email';
        };

        # Grab the approved comments for this post
        @comments
            = resultset('Comment')
            ->search(
            { post_id => $post->id, status => 'approved', reply_to => undef }
            ) if ($post);

        delete $template_params->{warning};
        delete $template_params->{in_reply_to};

        if (   ( $post->user_id && $user && $post->user_id == $user->{id} )
            or ( $user && $user->{is_admin} ) )
        {
            $template_params->{success}
                = 'Your comment has been submited. Thank you!';
        } else {
            $template_params->{success}
                = 'Your comment has been submited and it will be displayed as soon as the author accepts it. Thank you!';
        }
    } else {

        # The secret code inncorrect
        # Repopulate the fields with the data

        $template_params->{fields} = $parameters;
    }

    foreach my $comment (@comments) {
        my @comment_replies = resultset('Comment')->search(
            { reply_to => $comment->id, status => 'approved' },
            { order_by => { -asc => "comment_date" } }
        );
        foreach my $reply (@comment_replies) {
            my $el;
            map { $el->{$_} = $reply->$_ }
                ( 'avatar', 'fullname', 'comment_date', 'content' );
            $el->{uid}->{username} = $reply->uid->username if $reply->uid;
            push( @{ $comment->{comment_replies} }, $el );
        }
    }
    $template_params->{comments} = \@comments;

    PearlBee::Helpers::Captcha::new_captcha_code();

    template 'post', $template_params;
};

1;
