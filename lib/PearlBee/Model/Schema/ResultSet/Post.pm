package  PearlBee::Model::Schema::ResultSet::Post;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use PearlBee::Helpers::Util qw/string_to_slug generate_new_slug_name/;

use String::Util qw(trim);

=haed

Check if the slug is already used, if so generate a new slug or return the old one

=cut

sub check_slug {
    my ( $self, $slug, $post_id ) = @_;

    my $schema = $self->result_source->schema;
    $slug = string_to_slug($slug);

    my $found_slug
        = ($post_id)
        ? $schema->resultset('Post')
        ->search( { id => { '!=' => $post_id }, slug => $slug } )->first
        : $schema->resultset('Post')->find( { slug => $slug } );
    my $slug_changed = 0;

    if ($found_slug) {

        # Extract the posts with slugs starting the same with the submited slug
        my @posts_with_same_slug = $schema->resultset('Post')
            ->search( { slug => { like => "$slug%" } } );
        my @slugs;
        push @slugs, $_->slug foreach @posts_with_same_slug;

        $slug = generate_new_slug_name( $slug, \@slugs );
        $slug_changed = 1;
    }

    return ( $slug, $slug_changed );
}

sub post_slug_exists {
    my ( $self, $slug, $user_id ) = @_;

    my $schema = $self->result_source->schema;
    my $post   = $schema->resultset('Post')
        ->search( { slug => $slug, author => $user_id } )->first();

    return $post;
}

1;
