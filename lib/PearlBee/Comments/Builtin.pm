package PearlBee::Comments::Builtin;
use Moo;
use PearlBee::Comments::Builtin::AddComment;
use PearlBee::Comments::Builtin::Dashboard;

with 'PearlBee::Role::CommentsEngine';

has '+post_comment_count_template' =>
    ( default => sub {'comments/builtin/post_comment_count'}, );

has '+comment_form_template' =>
    ( default => sub {'comments/builtin/comment_form'}, );

has '+list_comments_template' =>
    ( default => sub {'comments/builtin/list_comments'}, );

has '+comments_dashboard_link' => (
    # FIXME: use uri_for somewhere
    default => sub { '/dashboard/comments' },
);

no Moo;
1;
