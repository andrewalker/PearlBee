-- Verify pearlbee:table_tag on pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

SELECT post_id, tag FROM post_tag WHERE FALSE;

ROLLBACK;
