-- Deploy pearlbee:table_post to pg
-- requires: schema_pearlbee
-- requires: table_user

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

CREATE TYPE post_status_type AS ENUM (
    'published',
    'trash',
    'draft'
);

CREATE TABLE post (
    id serial NOT NULL,
    title text NOT NULL,
    slug text NOT NULL,
    abstract text,
    cover text NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status post_status_type DEFAULT 'draft'::post_status_type,
    author integer NOT NULL,
    PRIMARY KEY(id),
    UNIQUE(slug),
    FOREIGN KEY (author) REFERENCES "user"(id)
);

COMMIT;
