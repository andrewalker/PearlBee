-- Revert pearlbee:schema_pearlbee from pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;

DROP SCHEMA pearlbee;

COMMIT;
