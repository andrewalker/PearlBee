-- Revert pearlbee:table_post from pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

DROP TABLE "post";
DROP TYPE post_status_type;

COMMIT;
