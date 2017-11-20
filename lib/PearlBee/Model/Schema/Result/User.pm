use utf8;
package PearlBee::Model::Schema::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

PearlBee::Model::Schema::Result::User

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

=head1 TABLE: C<user>

=cut

__PACKAGE__->table("user");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'user_id_seq'

=head2 first_name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 last_name

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 200

=head2 password

  data_type: 'char'
  is_nullable: 0
  size: 59

=head2 register_date

  data_type: 'timestamp'
  default_value: CURRENT_TIMESTAMP
  is_nullable: 0

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 company

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 telephone

  data_type: 'varchar'
  is_nullable: 1
  size: 12

=head2 role

  data_type: 'enum'
  default_value: 'author'
  extra: {custom_type_name => "user_role_type",list => ["author","admin"]}
  is_nullable: 0

=head2 activation_key

  data_type: 'varchar'
  is_nullable: 1
  size: 100

=head2 status

  data_type: 'enum'
  default_value: 'deactivated'
  extra: {custom_type_name => "user_status_type",list => ["deactivated","activated","suspended","pending"]}
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "user_id_seq",
  },
  "first_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "last_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 200 },
  "password",
  { data_type => "char", is_nullable => 0, size => 59 },
  "register_date",
  {
    data_type     => "timestamp",
    default_value => \"CURRENT_TIMESTAMP",
    is_nullable   => 0,
  },
  "email",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "company",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "telephone",
  { data_type => "varchar", is_nullable => 1, size => 12 },
  "role",
  {
    data_type => "enum",
    default_value => "author",
    extra => { custom_type_name => "user_role_type", list => ["author", "admin"] },
    is_nullable => 0,
  },
  "activation_key",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "status",
  {
    data_type => "enum",
    default_value => "deactivated",
    extra => {
      custom_type_name => "user_status_type",
      list => ["deactivated", "activated", "suspended", "pending"],
    },
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<email>

=over 4

=item * L</email>

=back

=cut

__PACKAGE__->add_unique_constraint("email", ["email"]);

=head2 C<username>

=over 4

=item * L</username>

=back

=cut

__PACKAGE__->add_unique_constraint("username", ["username"]);

=head1 RELATIONS

=head2 categories

Type: has_many

Related object: L<PearlBee::Model::Schema::Result::Category>

=cut

__PACKAGE__->has_many(
  "categories",
  "PearlBee::Model::Schema::Result::Category",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 comments

Type: has_many

Related object: L<PearlBee::Model::Schema::Result::Comment>

=cut

__PACKAGE__->has_many(
  "comments",
  "PearlBee::Model::Schema::Result::Comment",
  { "foreign.uid" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 posts

Type: has_many

Related object: L<PearlBee::Model::Schema::Result::Post>

=cut

__PACKAGE__->has_many(
  "posts",
  "PearlBee::Model::Schema::Result::Post",
  { "foreign.user_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07047 @ 2017-11-20 10:43:58
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Sn/rnz8s4TtebVDE8C9AIA

__PACKAGE__->add_columns(
    password => {
        data_type           => "char",
        is_nullable         => 0,
        size                => 59,
        encode_column       => 1,
        encode_class        => 'Crypt::Eksblowfish::Bcrypt',
        encode_args         => { key_nul => 0, cost => 8 },
        encode_check_method => 'check_password',
    }
);

=head

Check if the user has administration authority

=cut

sub is_admin {
    my ($self) = shift;

    return 1 if ( $self->role eq 'admin' );

    return 0;
}

=head

Check if the user has author authority

=cut

sub is_author {
    my ($self) = shift;

    return 1 if ( $self->role eq 'author' );

    return 0;
}

=head

Check if the user is active

=cut

sub is_active {
    my ($self) = shift;

    return 1 if ( $self->role eq 'activated' );

    return 0;
}

=head

Check if the user is deactivated

=cut

sub is_deactive {
    my ($self) = shift;

    return 1 if ( $self->role eq 'deactivated' );

    return 0;
}

=head

Status changes

=cut

sub deactivate {
    my $self = shift;

    $self->update( { status => 'deactivated' } );
}

sub activate {
    my $self = shift;

    $self->update( { status => 'activated' } );
}

sub suspend {
    my $self = shift;

    $self->update( { status => 'suspended' } );
}

sub allow {
    my $self = shift;

    # set a password for the user

    # welcome the user in an email

    $self->update( { status => 'deactivated' } );
}

sub uri {
    '/posts/user/' . $_[0]->username . ( $PearlBee::is_static && '.html ' );
}

1;
