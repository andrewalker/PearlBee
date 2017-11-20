-- Verify pearlbee:table_user on pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

SELECT id, name, username, email, password, role, status, registered_at, last_login FROM "user" WHERE FALSE;

ROLLBACK;
