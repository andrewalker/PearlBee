-- Revert pearlbee:registration_token_reason from pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

ALTER TABLE registration_token
    DROP COLUMN reason;

DROP TYPE registration_token_reason;

COMMIT;
