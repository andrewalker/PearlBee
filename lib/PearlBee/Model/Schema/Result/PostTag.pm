use utf8;
package PearlBee::Model::Schema::Result::PostTag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PearlBee::Model::Schema::Result::PostTag

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::EncodedColumn>

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("EncodedColumn", "InflateColumn::DateTime");

=head1 TABLE: C<post_tag>

=cut

__PACKAGE__->table("post_tag");

=head1 ACCESSORS

=head2 post_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 tag

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "post_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "tag",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tag>

=item * L</post_id>

=back

=cut

__PACKAGE__->set_primary_key("tag", "post_id");

=head1 RELATIONS

=head2 post

Type: belongs_to

Related object: L<PearlBee::Model::Schema::Result::Post>

=cut

__PACKAGE__->belongs_to(
  "post",
  "PearlBee::Model::Schema::Result::Post",
  { id => "post_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-11-20 13:23:00
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:39CDcye/6TW4arBILkqjpQ

sub uri { '/posts/tag/' . $_[0]->slug . ( $PearlBee::is_static && '.html ' ) }

sub edit_uri { '/dashboard/tags/edit/' . $_[0]->id }

sub delete_uri { '/dashboard/tags/delete/' . $_[0]->id }

1;
