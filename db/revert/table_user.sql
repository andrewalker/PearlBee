-- Revert pearlbee:table_user from pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

DROP TABLE "user";
DROP TYPE user_role_type;
DROP TYPE user_status_type;

COMMIT;
