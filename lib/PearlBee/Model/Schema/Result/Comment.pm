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
  is_nullable: 1

=head2 fullname

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 200

=head2 website

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 avatar

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 comment_date

  data_type: 'timestamp'
  default_value: CURRENT_TIMESTAMP
  is_nullable: 0

=head2 status

  data_type: 'enum'
  default_value: 'pending'
  extra: {custom_type_name => "comment_status_type",list => ["approved","spam","pending","trash"]}
  is_nullable: 1

=head2 post_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 uid

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 reply_to

  data_type: 'integer'
  is_nullable: 1

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
  { data_type => "text", is_nullable => 1 },
  "fullname",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "email",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "website",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "avatar",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "comment_date",
  {
    data_type     => "timestamp",
    default_value => \"CURRENT_TIMESTAMP",
    is_nullable   => 0,
  },
  "status",
  {
    data_type => "enum",
    default_value => "pending",
    extra => {
      custom_type_name => "comment_status_type",
      list => ["approved", "spam", "pending", "trash"],
    },
    is_nullable => 1,
  },
  "post_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "uid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "reply_to",
  { data_type => "integer", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 post

Type: belongs_to

Related object: L<PearlBee::Model::Schema::Result::Post>

=cut

__PACKAGE__->belongs_to(
  "post",
  "PearlBee::Model::Schema::Result::Post",
  { id => "post_id" },
  { is_deferrable => 1, on_delete => "RESTRICT", on_update => "RESTRICT" },
);

=head2 uid

Type: belongs_to

Related object: L<PearlBee::Model::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "uid",
  "PearlBee::Model::Schema::Result::User",
  { id => "uid" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-11-20 10:43:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lnoAmj72aNLeKvk6BNzFew

# You can replace this text with custom code or comments, and it will be preserved on regeneration

sub approve {
    my ( $self, $user ) = @_;

    $self->update( { status => 'approved' } )
        if ( $self->is_authorized($user) );
}

sub trash {
    my ( $self, $user ) = @_;

    $self->update( { status => 'trash' } ) if ( $self->is_authorized($user) );
}

sub spam {
    my ( $self, $user ) = @_;

    $self->update( { status => 'spam' } ) if ( $self->is_authorized($user) );
}

sub pending {
    my ( $self, $user ) = @_;

    $self->update( { status => 'pending' } )
        if ( $self->is_authorized($user) );
}

=haed

Check if the user has enough authorization for modifying

=cut

sub is_authorized {
    my ( $self, $user ) = @_;
    return ( $user->is_admin || $self->post->user_id == $user->id );
}

sub replies {
    my ($self) = @_;

    my $replies = $self->result_source->resultset->search(
        {
            # FIXME: reply_to should really be a proper foreign key
            reply_to    => $self->id,
            'me.status' => 'approved',
        },
        {
            order_by   => { -asc => "comment_date" },
            join       => ['uid'],
            '+columns' => ['uid.username'],
        }
    );

    return [ $replies->all ];
}

1;
