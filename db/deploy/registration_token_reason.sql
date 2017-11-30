-- Deploy pearlbee:registration_token_reason to pg
-- requires: table_registration_token

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

CREATE TYPE registration_token_reason AS ENUM('verify-email-address', 'reset-password');

ALTER TABLE registration_token
    ADD COLUMN reason registration_token_reason NOT NULL
        DEFAULT 'verify-email-address'::registration_token_reason;

COMMIT;
