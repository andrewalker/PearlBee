-- Revert pearlbee:table_comment from pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

DROP TABLE "comment";
DROP TYPE comment_status_type;

COMMIT;
