-- Verify pearlbee:table_comment on pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

SELECT id, content, created_at, status, author, post FROM "comment" WHERE FALSE;

ROLLBACK;
