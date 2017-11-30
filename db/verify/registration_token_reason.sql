-- Verify pearlbee:registration_token_reason on pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

SELECT reason FROM registration_token WHERE FALSE;

ROLLBACK;
