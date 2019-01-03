use utf8;
package PearlBee::Model::Schema::Result::Comment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PearlBee::Model::Schema::Result::Comment

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

=head1 TABLE: C<comment>

=cut

__PACKAGE__->table("comment");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'comment_id_seq'

=head2 content

  data_type: 'text'
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0

=head2 status

  data_type: 'enum'
  default_value: 'published'
  extra: {custom_type_name => "comment_status_type",list => ["published","trash"]}
  is_nullable: 1

=head2 author

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 post

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "comment_id_seq",
  },
  "content",
  { data_type => "text", is_nullable => 0 },
  "created_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
  "status",
  {
    data_type => "enum",
    default_value => "published",
    extra => {
      custom_type_name => "comment_status_type",
      list => ["published", "trash"],
    },
    is_nullable => 1,
  },
  "author",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "post",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 author

Type: belongs_to

Related object: L<PearlBee::Model::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "author",
  "PearlBee::Model::Schema::Result::User",
  { id => "author" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 post

Type: belongs_to

Related object: L<PearlBee::Model::Schema::Result::Post>

=cut

__PACKAGE__->belongs_to(
  "post",
  "PearlBee::Model::Schema::Result::Post",
  { id => "post" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2019-01-02 16:16:41
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ezeggEU8RX4DGpyw1xbZHw

use Time::Ago;

sub created_at_time_ago {
    my $self = shift;
    # FIXME: we force English here because otherwise Time::Ago will use the
    # system locale. That would be fine, except the rest of the content is not
    # localized, so this could mean only the time is translated, while the rest
    # is English. Better to keep it in English only until we implement i18n in
    # the whole application.
    local $ENV{LANGUAGE} = 'en';
    my $diff = DateTime->now->set_time_zone('UTC')->epoch - $self->created_at->set_time_zone('UTC')->epoch;
    return Time::Ago->in_words($diff) . ' ago';
}

1;
