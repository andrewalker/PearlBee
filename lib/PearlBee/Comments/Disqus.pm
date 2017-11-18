package PearlBee::Comments::Disqus;
use Moo;
use Types::Standard qw/HashRef Str/;
with 'PearlBee::Role::CommentsEngine';

has shortname => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has '+post_comment_count_template' =>
    ( default => sub {'comments/disqus/post_comment_count.tt'}, );

has '+list_comments_template' =>
    ( default => sub {'comments/disqus/list_comments.tt'}, );

has '+scripts_template' => ( default => sub {'comments/disqus/scripts.tt'}, );

has '+comments_dashboard_link' =>
    ( default => sub { 'https://' . $_[0]->shortname . '.disqus.com/admin/' },
    );

no Moo;

1;
