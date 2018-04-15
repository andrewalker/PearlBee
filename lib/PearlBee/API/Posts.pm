package PearlBee::API::Posts;

# ABSTRCT: Posts-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use PearlBee::Helpers::Pagination qw<get_total_pages get_previous_next_link>;

my %sort = map +($_, $_), qw( id created_at updated_at );
my %dir  = map +($_, "-$_"), qw( asc desc );

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

sub api_posts_endpoint {
    my ($author) = @_;
    my $per_page  = int(query_parameters->{'per_page'} // 0) || 10;
    my $page      = int(query_parameters->{'page'}     // 0) || 1;
    my $sort      = $sort{ query_parameters->{'sort'}      || 'created_at' } || 'created_at';
    my $direction = $dir{  query_parameters->{'direction'} || 'desc' }       || '-desc';

    if ($per_page > 50) {
        $per_page = 50;
    }

    my $posts = search_posts({
        author    => $author,
        per_page  => $per_page,
        page      => $page,
        sort      => $sort,
        direction => $direction,
        tags      => query_parameters->{'tags'},
        filter    => query_parameters->{'filter'},
    });

    send_as JSON => { posts => $posts, };
}

sub search_posts {
    my ($params) = @_;
    my (@ids, @filter_query);

    # XXX: This is complicated... if we're too permissive, we can open
    # ourselves for DoS. We'll have to be careful when combining filters and
    # tags. For now, we'll allow only one or the other. With the current
    # implementation, this wouldn't be possible because we're limiting the rows
    # for the tag search here.
    if (my $tags = $params->{tags}) {
        my @tags = split /,/, $tags;
        # at most 3 tags
        @tags = splice @tags, 0, 3;
        @ids = map $_->{post_id}, search_tags(\@tags, $params->{per_page}, $params->{author});
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

    my @author_query = $params->{author} ? ( 'me.author' => $params->{author} ) : ();

    my @posts = map {
        $_->{url} = uri_for('/' . $_->{author}{username} . '/' . $_->{slug});
        $_->{tags} = [ sort map $_->{tag}, @{ delete $_->{post_tags} } ];
        $_;
    } resultset('Post')->search(
        { 'me.status' => 'published', @id_query, @filter_query, @author_query },
        {
            order_by     => { $params->{direction} => $params->{sort} },
            rows         => $params->{per_page},
            page         => $params->{page},
            join         => 'author',
            prefetch     => 'post_tags',
            '+select'    => ['author.username', 'author.name'],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    )->all;

    return \@posts;
}

sub search_tags {
    my ($tags, $per_page, $author_id) = @_;

    my $query
        = @$tags == 1
        ? { 'me.tag' => $tags->[0] }
        : { -or => [ map +{ 'me.tag' => $_ }, @$tags ] };
    my $options = {
        columns      => ['post_id'],
        result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        rows         => $per_page,
    };

    if ($author_id) {
        $options->{'join'} = 'post';
        $query->{'post.author'} = $author_id;
    }

    return resultset('PostTag')->search( $query, $options )->all;
}

1;
