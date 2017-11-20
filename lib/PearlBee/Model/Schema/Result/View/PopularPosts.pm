package PearlBee::Model::Schema::Result::View::PopularPosts;

# This view is used for grabbing popular posts based on the number of comments

use strict;
use warnings;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('tag');
__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(
    q[
    SELECT
      P.id AS id, COUNT(P.title) AS comments, P.title AS title, P.abstract AS abstract, P.slug AS slug
    FROM
      post as P
      INNER JOIN
        comment AS C
        ON
        C.post_id = P.id
    WHERE
      P.status = 'published'
    GROUP BY
      P.id, P.title, P.abstract, P.slug
    ORDER BY
      comments DESC
  ]
);

__PACKAGE__->add_columns(
    "id",
    { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
    "comments",
    { data_type => "integer", is_nullable => 0 },
    "title",
    { data_type => "text", is_nullable => 0 },
    "abstract",
    { data_type => "text", is_nullable => 0 },
    "slug",
    { data_type => "text", is_nullable => 0 },
);

__PACKAGE__->set_primary_key("id");

1;
