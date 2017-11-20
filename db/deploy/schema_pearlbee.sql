-- Deploy pearlbee:schema_pearlbee to pg

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;

CREATE SCHEMA pearlbee;

COMMIT;
