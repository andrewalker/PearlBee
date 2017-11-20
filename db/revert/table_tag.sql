-- Revert pearlbee:table_tag from pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

-- indexes are dropped along with the table;
DROP TABLE post_tag;

COMMIT;
