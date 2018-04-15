package PearlBee::API::Posts;

# ABSTRCT: Posts-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use PearlBee::Helpers::Pagination qw<get_total_pages get_previous_next_link>;

get '/api/posts' => sub {
    # Number of posts per page
    my $per_page = query_parameters->{'per_page'} || 10;
    my $page     = query_parameters->{'page'} || 1;

    my @posts = map {
        $_->{url} = uri_for('/' . $_->{author}{username} . '/' . $_->{slug});
        $_;
    } resultset('Post')->search(
        { 'me.status' => 'published' },
        {
            order_by => { -desc => "created_at" },
            rows     => $per_page,
            page     => $page,
            join     => 'author',
            '+select' => ['author.username', 'author.name'],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    )->all;

    send_as JSON => { posts => \@posts, };
};

1;
