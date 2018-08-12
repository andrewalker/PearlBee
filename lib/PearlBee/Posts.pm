package PearlBee::Posts;
# ABSTRACT: Posts-related paths

use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;

my $model = PearlBee::Model::Posts->new(
    user_rs     => resultset('User'),
    post_rs     => resultset('Post'),
    post_tag_rs => resultset('PostTag'),
    uri_for     => \&uri_for,
);

my %sort = map +($_, $_), qw( id created_at updated_at );
my %dir  = map +($_, "-$_"), qw( asc desc );

get '/posts' => sub {
    my $per_page  = int(query_parameters->{'per_page'} // 0) || 10;
    my $page      = int(query_parameters->{'page'}     // 0) || 1;
    my $sort      = $sort{ query_parameters->{'sort'}      || 'created_at' } || 'created_at';
    my $direction = $dir{  query_parameters->{'direction'} || 'desc' }       || '-desc';

    if ($per_page > 50) {
        $per_page = 50;
    }

    my @posts = $model->search_posts({
        per_page  => $per_page,
        page      => $page,
        sort      => $sort,
        direction => $direction,
        tags      => query_parameters->{'tags'},
        filter    => query_parameters->{'filter'},
    });

    # TODO: feature_image, cover_image from meta
    $_->{authors} = [ $_->{author} ] for @posts;

    template 'index' => { posts => \@posts, context => 'home' };
};

get '/users/:author' => sub {
    my $author    = route_parameters->{'author'};
    my $per_page  = int(query_parameters->{'per_page'} // 0) || 10;
    my $page      = int(query_parameters->{'page'}     // 0) || 1;
    my $sort      = $sort{ query_parameters->{'sort'}      || 'created_at' } || 'created_at';
    my $direction = $dir{  query_parameters->{'direction'} || 'desc' }       || '-desc';

    if ($per_page > 50) {
        $per_page = 50;
    }

    my @posts = $model->search_posts({
        author_username => $author,
        per_page        => $per_page,
        page            => $page,
        sort            => $sort,
        direction       => $direction,
        tags            => query_parameters->{'tags'},
        filter          => query_parameters->{'filter'},
    });

    # TODO: feature_image, cover_image from meta
    $_->{authors} = [ $_->{author} ] for @posts;

    template 'index' => { posts => \@posts, context => 'home' };
};

get '/:author/:slug' => sub {
    my $author = route_parameters->{'author'};
    my $slug   = route_parameters->{'slug'};

    my ($post) = $model->search_posts({
        author_username => $author,
        slug            => $slug,
    });

    if (!$post) {
        status 'not_found';
        return 'Post not found';
    }

    # TODO: feature_image, cover_image from meta
    # $post->{feature_image} = 'https://casper.ghost.org/v1.0.0/images/welcome.jpg';
    $post->{authors} = [ $post->{author} ];

    template post => { post => $post, context => 'post' };
};

1;
