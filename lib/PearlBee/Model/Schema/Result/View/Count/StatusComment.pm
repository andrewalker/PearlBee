package PearlBee::Model::Schema::Result::View::Count::StatusComment;

# This view is used for counting all stauts

use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('comment');
__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(
    q[
      SELECT
          SUM( CASE WHEN "status" = 'pending'  THEN 1 ELSE 0 END ) AS pending,
          SUM( CASE WHEN "status" = 'approved' THEN 1 ELSE 0 END ) AS approved,
          SUM( CASE WHEN "status" = 'trash'    THEN 1 ELSE 0 END ) AS trash,
          SUM( CASE WHEN "status" = 'spam'     THEN 1 ELSE 0 END ) AS spam,
          COUNT(*)                                                 AS total
      FROM
          "comment"
    ]
);

__PACKAGE__->add_columns(
    "pending",  { data_type => "integer", is_nullable => 0 },
    "approved", { data_type => "integer", is_nullable => 0 },
    "trash",    { data_type => "integer", is_nullable => 0 },
    "spam",     { data_type => "integer", is_nullable => 0 },
    "total",    { data_type => "integer", is_nullable => 0 },
);

sub get_all_status_counts {
    my $self = shift;

    return (
        $self->total, $self->approved, $self->trash,
        $self->spam,  $self->pending
    );
}

sub get_status_count {
    my ( $self, $status ) = @_;

    return
          ( $status eq 'pending' )  ? $self->pending
        : ( $status eq 'approved' ) ? $self->approved
        : ( $status eq 'trash' )    ? $self->trash
        :                             $self->spam;
}

1;
