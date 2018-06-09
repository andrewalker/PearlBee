package PearlBee::API::Posts;

# ABSTRCT: Posts-related paths
use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Auth::Tiny;
use Ref::Util qw(is_hashref is_ref is_blessed_scalarref is_arrayref);
use Text::Unidecode ();
use String::Truncate ();

# TODO: move this to a more appropriate place
use constant MAX_KEYS_POST_META  => 1000;
use constant MAX_POST_TAGS       => 1000;
use constant MAX_ABSTRACT_LENGTH => 1000;

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

    my ($public_post) = search_posts({
        id => $post_id
    });

    $public_post and
        return send_as JSON => { post => $public_post };

    if (my $user = session 'user_id') {
        my ($private_post) = search_posts({
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
    my $user    = resultset('User')->find($user_id);
    my $json    = decode_json( request->body );

    if ($json->{meta}) {
        is_hashref($json->{meta})
            or return send_as_bad_request({ error => q/meta has to be a JSON object/ });

        check_meta_deep($json->{meta})
            or return send_as_bad_request({ error => q/meta can't have deep data structures/ });

        check_meta_size($json->{meta})
            or return send_as_bad_request({ error => q/meta is too big/ });
    }

    if ($json->{tags}) {
        check_tags_format($json->{tags})
            or return send_as_bad_request({ error => q/tags are supposed to be an array of strings/ });

        check_tags_size($json->{tags})
            or return send_as_bad_request({ error => q/tags are too big/ });
    }

    my $post = $user->add_to_posts({
        title    => $json->{title},
        slug     => sluggify($json->{slug} || $json->{title}),
        abstract => abstractify($json->{abstract} || $json->{content}),
        content  => $json->{content},
        meta     => $json->{meta} ? encode_json($json->{meta}) : undef,
        status   => $json->{status},
    });

    $post->add_to_post_tags({ tag => $_ }) for @{ $json->{tags} || [] };

    status 'created';
    send_as JSON => {
        post => search_posts({ id => $post->id, published_only => 0 }),
    };
};



#################################################################
###                                                           ###
### Helper methods                                            ###
###                                                           ###
#################################################################

# TODO:
# move these to a separate module
sub check_meta_deep {
    for (values %{ $_[0] }) {
        # if it's a boolean, it will be a scalarref
        return 0 if is_ref($_) && !is_blessed_scalarref($_);
    }
    return 1;
}
sub check_meta_size {
    return keys %{ $_[0] } < MAX_KEYS_POST_META;
}
sub check_tags_format {
    return 0 if !is_arrayref( $_[0] );
    for (@{ $_[0] }) {
        return 0 if is_ref($_);
    }
    return 1;
}
sub check_tags_size {
    return @{ $_[0] } < MAX_POST_TAGS;
}

sub sluggify {
    my ( $str )  = @_;
    my $ldec_str = lc Text::Unidecode::unidecode($str);

    return $ldec_str =~ s/[^0-9a-z]+/-/gr
                     =~ s/^\-//gr
                     =~ s/\-$//gr;
}

sub abstractify {
    String::Truncate::elide($_[0], MAX_ABSTRACT_LENGTH, { at_space => 1 });
}

sub send_as_bad_request {
    status 'bad_request';
    send_as JSON => $_[0];
}

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

    my @posts = search_posts({
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

# TODO: move this to the model
sub search_posts {
    my ($params) = @_;
    my (@ids, @filter_query);

    if ($params->{id}) {
        @ids = $params->{id};
    }
    # XXX: This is complicated... if we're too permissive, we can open
    # ourselves for DoS. We'll have to be careful when combining filters and
    # tags. For now, we'll allow only one or the other. With the current
    # implementation, this wouldn't be possible because we're limiting the rows
    # for the tag search here.
    elsif (my $tags = $params->{tags}) {
        my @tags = split /,/, $tags;
        # at most 3 tags
        @tags = splice @tags, 0, 3;
        @ids = map $_->{post_id}, search_tags(\@tags, $params->{per_page}, $params->{author});
    }
    # TODO: fulltext search
    elsif (my $filter = $params->{'filter'}) {
        @filter_query = (
            -or => [
                { 'me.title'    => { -ilike => "\%$filter\%" } },
                { 'me.abstract' => { -ilike => "\%$filter\%" } },
            ]
        );
    }

    # Some endpoints can access all posts, others can only access the published
    # posts. To be safe, the default is to show only the published ones.
    my $only_published = exists $params->{only_published} ? $params->{only_published} : 1;
    my @status_query
        = $only_published
        ? ( 'me.status' => 'published', 'author.verified_by_peers' => 1 )
        : ();

    my @paging_and_sorting = !$params->{id} ? (
        order_by     => { $params->{direction} => $params->{sort} },
        rows         => $params->{per_page},
        page         => $params->{page},
    ) : ();

    my @id_query
        = @ids == 1 ? ( 'me.id' => $ids[0] )
        : @ids ? ( 'me.id' => { -in => \@ids } )
        :        ();
    my @author_query = $params->{author} ? ( 'me.author' => $params->{author} ) : ();

    my @posts = map {
        $_->{url} = uri_for('/' . $_->{author}{username} . '/' . $_->{slug});
        $_->{tags} = [ sort map $_->{tag}, @{ delete $_->{post_tags} } ];
        $_->{meta} = decode_json( delete $_->{meta} )
            if $_->{meta};

        # strip fractional seconds:
        $_->{'created_at'} =~ s/(\.[0-9]+)(\+)/$2/;
        $_->{'updated_at'} =~ s/(\.[0-9]+)(\+)/$2/;

        $_;
    } resultset('Post')->search(
        { @status_query, @id_query, @filter_query, @author_query },
        {
            @paging_and_sorting,
            join         => 'author',
            prefetch     => 'post_tags',
            '+select'    => ['author.username', 'author.name'],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    )->all;

    return @posts;
}

# TODO: move this to the model
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
