-- Deploy pearlbee:table_registration_token to pg
-- requires: schema_pearlbee
-- requires: table_user

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

CREATE TABLE registration_token (
    token text NOT NULL,
    "user" integer NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    voided_at timestamp with time zone NULL,
    PRIMARY KEY(token),
    FOREIGN KEY ("user") REFERENCES "user"(id) ON UPDATE CASCADE ON DELETE CASCADE
);

COMMIT;
