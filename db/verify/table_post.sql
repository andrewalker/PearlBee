-- Verify pearlbee:table_post on pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

SELECT id, title, slug, abstract, cover, content, created_at, updated_at, status, author FROM "post" WHERE FALSE;

ROLLBACK;
