-- Deploy pearlbee:table_tag to pg
-- requires: schema_pearlbee
-- requires: table_post

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

CREATE TABLE post_tag (
    post_id integer NOT NULL,
    tag TEXT NOT NULL,
    PRIMARY KEY (tag, post_id),
    FOREIGN KEY(post_id) REFERENCES post(id)
);

CREATE INDEX post_tag_idx_tag ON post_tag USING btree(tag);

COMMIT;
