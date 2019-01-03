package PearlBee::Feeds;
# ABSTRACT: Feeds for Pearlbee

use Dancer2 appname => 'PearlBee';
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::Feed;
use PearlBee::Model::Posts;
use DateTime::Format::Strptime;

get '/rss' => sub {
    return feed('rss');
};

get '/atom' => sub {
    return feed('atom');
};

my $model = PearlBee::Model::Posts->new(
    user_rs     => resultset('User'),
    post_rs     => resultset('Post'),
    post_tag_rs => resultset('PostTag'),
    uri_for     => \&uri_for,
);

my %sort = map +($_, $_), qw( id created_at updated_at );
my %dir  = map +($_, "-$_"), qw( asc desc );

sub feed {
    my $format = shift;

    my $per_page  = int(query_parameters->{'per_page'} // 0) || 10;
    my $page      = int(query_parameters->{'page'}     // 0) || 1;
    my $sort      = $sort{ query_parameters->{'sort'}      || 'created_at' } || 'created_at';
    my $direction = $dir{  query_parameters->{'direction'} || 'desc' }       || '-desc';

    if ($per_page > 50) {
        $per_page = 50;
    }

    my @posts = $model->search_posts({
        per_page        => $per_page,
        page            => $page,
        sort            => $sort,
        direction       => $direction,
        tags            => query_parameters->{'tags'},
        filter          => query_parameters->{'filter'},
    });

    my $parser = DateTime::Format::Strptime->new( pattern => '%F %T%z' );

    return create_feed(
        format    => $format,
        title     => config->{site}{name},
        tagline   => config->{site}{tagline},
        self_link => uri_for('/'),
        entries   => [
            map +{
                title    => $_->{title},
                summary  => $_->{abstract},
                link     => $_->{url},
                issued   => $parser->parse_datetime($_->{created_at}),
                modified => $parser->parse_datetime($_->{updated_at}),
                author   => $_->{author}{name},
            },
            @posts
        ],
    );
}

1;
