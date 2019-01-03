package PearlBee::Model::Posts;

use Moo;

use Ref::Util qw(is_hashref is_ref is_blessed_scalarref is_arrayref);
use Text::Unidecode ();
use String::Truncate ();
use JSON::MaybeXS;
use Gravatar::URL;

has uri_for => ( is => 'ro', required => 1 );

has user_rs => (
    is => 'ro',
    required => 1,
);

has post_tag_rs => (
    is => 'ro',
    required => 1,
);

has post_rs => (
    is => 'ro',
    required => 1,
);

has max_keys_post_meta => (
    is      => 'ro',
    default => sub { 1000 },
);

has max_post_tags => (
    is      => 'ro',
    default => sub { 1000 },
);

has max_abstract_length => (
    is      => 'ro',
    default => sub { 1000 },
);

sub create_post {
    my ($self, $user_id, $data) = @_;

    my $user = $self->user_rs->find($user_id)
        or return (undef, 'user-not-found');

    if ($data->{meta}) {
        is_hashref($data->{meta})
            or return (undef, 'meta-not-json-object');

        $self->check_meta_deep($data->{meta})
            or return (undef, 'meta-deep');

        $self->check_meta_size($data->{meta})
            or return (undef, 'meta-too-big');
    }

    if ($data->{tags}) {
        $self->check_tags_format($data->{tags})
            or return (undef, 'tags-not-string-array');

        $self->check_tags_size($data->{tags})
            or return (undef, 'tags-too-big');
    }

    if ($data->{abstract}) {
        $self->check_abstract_size($data->{abstract})
            or return (undef, 'abstract-too-big');
    }

    my $post = $user->add_to_posts({
        title    => $data->{title},
        slug     => $self->sluggify($data->{slug} || $data->{title}),
        abstract => $self->abstractify($data->{abstract} || $data->{content}),
        content  => $data->{content},
        meta     => $data->{meta} ? encode_json($data->{meta}) : undef,
        status   => $data->{status},
    });

    $post
        or return (undef, 'post-not-created');

    $post->add_to_post_tags({ tag => $_ }) for @{ $data->{tags} || [] };

    return ($post, undef);
}

sub update_post {
    my ($self, $user_id, $post_id, $data) = @_;
    my $post = $self->post_rs->find($post_id);

    if (!$post) {
        return (undef, 'post-not-found');
    }
    if (!$post->can_be_edited_by($user_id)) {
        return (undef, 'forbidden');
    }

    my $updated = 0;
    my @post_columns = qw/title slug status content abstract/;
    my %to_be_updated = map +($_, $data->{$_}),
                        grep exists $data->{$_}, @post_columns;

    if ($data->{meta}) {
        is_hashref($data->{meta})
            or return (undef, 'meta-not-json-object');

        $self->check_meta_deep($data->{meta})
            or return (undef, 'meta-deep');

        $self->check_meta_size($data->{meta})
            or return (undef, 'meta-too-big');

        $to_be_updated{meta} = encode_json(
            merge_patch( $post->meta ? decode_json( $post->meta ) : {}, $data->{meta} )
        );
    }

    if ($data->{tags}) {
        $self->check_tags_format($data->{tags})
            or return (undef, 'tags-not-string-array');

        $self->check_tags_size($data->{tags})
            or return (undef, 'tags-too-big');
    }

    if ($data->{abstract}) {
        $self->check_abstract_size($data->{abstract})
            or return (undef, 'abstract-too-big');
    }

    if (%to_be_updated) {
        $post->update(\%to_be_updated);
        $updated++;
    }
    if (my $tags = $data->{tags}) {
        $post->delete_related('post_tags');
        $post->add_to_post_tags({ tag => $_ }) for @$tags;
        $updated++;
    }

    if (!$updated) {
        return (undef, 'nothing-to-update');
    }

    $post->update({  updated_at => \'now()' });
    return ($post, undef);
}

sub search_posts {
    my ($self, $params) = @_;
    my (@ids, @slug_query, @filter_query);

    if ($params->{id}) {
        @ids = $params->{id};
    }
    elsif ($params->{slug}) {
        @slug_query = (slug => $params->{slug});
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
        @ids = map $_->{post_id}, $self->search_tags(\@tags, $params->{per_page}, $params->{author});
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

    my @paging_and_sorting = !$params->{slug} && !$params->{id} ? (
        order_by     => { $params->{direction} => $params->{sort} },
        rows         => $params->{per_page},
        page         => $params->{page},
    ) : ();

    my @id_query
        = @ids == 1 ? ( 'me.id' => $ids[0] )
        : @ids ? ( 'me.id' => { -in => \@ids } )
        :        ();
    my @author_query
        = $params->{author} ? ( 'me.author' => $params->{author} )
        : $params->{author_username}
        ? ( 'author.username', $params->{author_username} )
        : ();

    my @posts = map {
        $_->{url} = $self->uri_for->('/' . $_->{author}{username} . '/' . $_->{slug});
        $_->{tags} = [ sort map $_->{tag}, @{ delete $_->{post_tags} } ];
        $_->{meta} = decode_json( delete $_->{meta} )
            if $_->{meta};

        # strip fractional seconds:
        $_->{'created_at'} =~ s/(\.[0-9]+)(\+)/$2/;
        $_->{'updated_at'} =~ s/(\.[0-9]+)(\+)/$2/;

        $_;
    } $self->post_rs->search(
        { @status_query, @id_query, @slug_query, @filter_query, @author_query },
        {
            @paging_and_sorting,
            join         => 'author',
            prefetch     => 'post_tags',
            '+select'    => ['author.username', 'author.name'],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    )->all;

    my @pager;
    if ($params->{with_pagination}) {
        push @pager, $self->post_rs->search({
            @status_query, @id_query, @slug_query, @filter_query, @author_query
        },
        {
            @paging_and_sorting,
            join => ['author','post_tags'],
        })->pager;
    }

    return (@pager, @posts);
}

sub search_tags {
    my ($self, $tags, $per_page, $author_id) = @_;

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

    return $self->post_tag_rs->search( $query, $options )->all;
}

#################################################################
###                                                           ###
### Helper methods                                            ###
###                                                           ###
#################################################################

# TODO:
# move these to a separate module

sub merge_patch {
    my ($original, $patch) = @_;

    for (keys %$patch) {
        if (! defined $patch->{$_}) {
            delete $original->{$_};
        }
        else {
            $original->{$_} = $patch->{$_};
        }
    }

    return $original;
}
sub check_meta_deep {
    my ($self, $meta) = @_;
    for (values %$meta) {
        # if it's a boolean, it will be a scalarref
        return 0 if is_ref($_) && !is_blessed_scalarref($_);
    }
    return 1;
}
sub check_meta_size {
    my ($self, $meta) = @_;
    return keys %$meta < $self->max_keys_post_meta;
}
sub check_abstract_size {
    my ($self, $str) = @_;
    return length $str < $self->max_abstract_length;
}
sub check_tags_format {
    my ($self, $tags) = @_;
    return 0 if !is_arrayref( $tags );
    for (@$tags) {
        return 0 if is_ref($_);
    }
    return 1;
}
sub check_tags_size {
    my ($self, $tags) = @_;
    return @$tags < $self->max_post_tags;
}
sub sluggify {
    my ( $self, $str )  = @_;
    my $ldec_str = lc Text::Unidecode::unidecode($str);

    return $ldec_str =~ s/[^0-9a-z]+/-/gr
                     =~ s/^\-//gr
                     =~ s/\-$//gr;
}
sub abstractify {
    my ($self, $str) = @_;
    String::Truncate::elide($str, $self->max_abstract_length, { at_space => 1 });
}

1;
