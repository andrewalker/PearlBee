package PearlBee::API::Posts;

# ABSTRCT: Posts-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use PearlBee::Helpers::Pagination qw<get_total_pages get_previous_next_link>;

my %sort = map +($_, $_), qw( id created_at updated_at );
my %dir  = map +($_, "-$_"), qw( asc desc );

get '/api/posts' => sub {
    my $per_page  = int(query_parameters->{'per_page'} // 0) || 10;
    my $page      = int(query_parameters->{'page'}     // 0) || 1;
    my $sort      = $sort{ query_parameters->{'sort'}      || 'created_at' } || 'created_at';
    my $direction = $dir{  query_parameters->{'direction'} || 'desc' }       || '-desc';

    if ($per_page > 50) {
        $per_page = 50;
    }

    my (@ids, @filter_query);

    # XXX: This is complicated... if we're too permissive, we can open
    # ourselves for DoS. We'll have to be careful when combining filters and
    # tags. For now, we'll allow only one or the other. With the current
    # implementation, this wouldn't be possible because we're limiting the rows
    # for the tag search here.
    if (my $tags = query_parameters->{'tags'}) {
        my @tags = split /,/, $tags;
        # at most 3 tags
        @tags = splice @tags, 0, 3;
        my $tag_query = @tags == 1 ? { tag => $tags[0] } : { -or => [ map +{ tag => $_ }, \@tags ] };
        @ids = map $_->{post_id}, resultset('PostTag')->search(
            $tag_query,
            {
                columns      => ['post_id'],
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                rows         => $per_page,
            }
        )->all;
    }
    # TODO: fulltext search
    elsif (my $filter = query_parameters->{'filter'}) {
        @filter_query = (
            -or => [
                { 'me.title'    => { -ilike => "\%$filter\%" } },
                { 'me.abstract' => { -ilike => "\%$filter\%" } },
            ]
        );
    }

    my @id_query = @ids ? ('me.id' => { -in => \@ids }) : ();

    my @posts = map {
        $_->{url} = uri_for('/' . $_->{author}{username} . '/' . $_->{slug});
        $_->{tags} = [ sort map $_->{tag}, @{ delete $_->{post_tags} } ];
        $_;
    } resultset('Post')->search(
        { 'me.status' => 'published', @id_query, @filter_query },
        {
            order_by     => { $direction => $sort },
            rows         => $per_page,
            page         => $page,
            join         => 'author',
            prefetch     => 'post_tags',
            '+select'    => ['author.username', 'author.name'],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    )->all;

    send_as JSON => { posts => \@posts, };
};

1;
