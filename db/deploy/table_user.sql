-- Deploy pearlbee:table_user to pg
-- requires: schema_pearlbee

BEGIN;

SET client_encoding = 'UTF8';
SET client_min_messages = warning;
SET search_path = pearlbee, pg_catalog;

CREATE TYPE user_role_type AS ENUM ( 'author', 'admin' );

CREATE TYPE user_status_type AS ENUM (
    'activated',
    'banned',
    'pending'
);

CREATE TABLE "user" (
    id serial NOT NULL,
    name text NULL,
    username text NOT NULL UNIQUE,
    email text NOT NULL UNIQUE,
    password character(59) NOT NULL,
    role  user_role_type DEFAULT 'author'::user_role_type NOT NULL,
    status user_status_type DEFAULT 'pending'::user_status_type NOT NULL,
    registered_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_login timestamp with time zone NULL,
    PRIMARY KEY(id)
);

COMMIT;
