-- Revert pearlbee:table_registration_token from pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

DROP TABLE registration_token;

COMMIT;
