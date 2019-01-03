-- Deploy pearlbee:table_comment to pg
-- requires: table_user
-- requires: table_post

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

CREATE TYPE comment_status_type AS ENUM( 'published', 'trash' );

CREATE TABLE "comment" (
    id serial NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status comment_status_type DEFAULT 'published'::comment_status_type,
    author integer NOT NULL,
    post integer NOT NULL,
    PRIMARY KEY(id),
    FOREIGN KEY (author) REFERENCES "user"(id),
    FOREIGN KEY (post) REFERENCES "post"(id)
);

COMMIT;
