use utf8;
package PearlBee::Model::Schema::Result::Post;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PearlBee::Model::Schema::Result::Post

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

=head1 TABLE: C<post>

=cut

__PACKAGE__->table("post");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'post_id_seq'

=head2 title

  data_type: 'text'
  is_nullable: 0

=head2 slug

  data_type: 'text'
  is_nullable: 0

=head2 meta

  data_type: 'jsonb'
  is_nullable: 1

=head2 abstract

  data_type: 'text'
  is_nullable: 1

=head2 content

  data_type: 'text'
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp with time zone'
  default_value: CURRENT_TIMESTAMP
  is_nullable: 0

=head2 updated_at

  data_type: 'timestamp with time zone'
  default_value: CURRENT_TIMESTAMP
  is_nullable: 0

=head2 status

  data_type: 'enum'
  default_value: 'draft'
  extra: {custom_type_name => "post_status_type",list => ["published","trash","draft"]}
  is_nullable: 1

=head2 author

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
    sequence          => "post_id_seq",
  },
  "title",
  { data_type => "text", is_nullable => 0 },
  "slug",
  { data_type => "text", is_nullable => 0 },
  "meta",
  { data_type => "jsonb", is_nullable => 1 },
  "abstract",
  { data_type => "text", is_nullable => 1 },
  "content",
  { data_type => "text", is_nullable => 0 },
  "created_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"CURRENT_TIMESTAMP",
    is_nullable   => 0,
  },
  "updated_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"CURRENT_TIMESTAMP",
    is_nullable   => 0,
  },
  "status",
  {
    data_type => "enum",
    default_value => "draft",
    extra => {
      custom_type_name => "post_status_type",
      list => ["published", "trash", "draft"],
    },
    is_nullable => 1,
  },
  "author",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<post_slug_key>

=over 4

=item * L</slug>

=back

=cut

__PACKAGE__->add_unique_constraint("post_slug_key", ["slug"]);

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

=head2 post_tags

Type: has_many

Related object: L<PearlBee::Model::Schema::Result::PostTag>

=cut

__PACKAGE__->has_many(
  "post_tags",
  "PearlBee::Model::Schema::Result::PostTag",
  { "foreign.post_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2018-04-14 14:07:02
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:XSVFHu0dVPO9Ic43XoeM9w


# You can replace this text with custom code or comments, and it will be preserved on regeneration

=head

Get the number of comments for this post

=cut

sub nr_of_comments {
    my ($self) = @_;

    my @post_comments = $self->comments;
    my @comments = grep { $_->status eq 'approved' } @post_comments;

    return scalar @comments;
}

=head

Get all tags as a string sepparated by a comma

=cut

sub get_string_tags {
    my ($self) = @_;

    my @tag_names;
    my @post_tags = $self->post_tags;
    push( @tag_names, $_->tag->name ) foreach (@post_tags);

    my $joined_tags = join( ', ', @tag_names );

    return $joined_tags;
}

=head 

Status updates

=cut

sub publish {
    my ( $self, $user ) = @_;

    $self->update( { status => 'published' } )
        if ( $self->is_authorized($user) );
}

sub draft {
    my ( $self, $user ) = @_;

    $self->update( { status => 'draft' } ) if ( $self->is_authorized($user) );
}

sub trash {
    my ( $self, $user ) = @_;

    $self->update( { status => 'trash' } ) if ( $self->is_authorized($user) );
}

=haed

Check if the user has enough authorization for modifying

=cut

sub is_authorized {
    my ( $self, $user ) = @_;

    my $schema     = $self->result_source->schema;
    my $authorized = 0;
    $authorized = 1 if ( $user->is_admin );
    $authorized = 1 if ( !$user->is_admin && $self->author->id == $user->id );

    return $authorized;
}

sub uri { '/posts/' . $_[0]->slug . ( $PearlBee::is_static && '.html ' ) }

sub edit_uri { '/dashboard/posts/edit/' . $_[0]->slug }

sub get_comments {
    my ($self) = @_;

    return [
        $self->comments->search(
            {
                status   => 'approved',
                reply_to => undef,
            }
        )->all
    ];
}

1;
