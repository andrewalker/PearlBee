-- Verify pearlbee:table_registration_token on pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

SELECT token, "user", created_at, voided_at FROM registration_token WHERE FALSE;

ROLLBACK;
