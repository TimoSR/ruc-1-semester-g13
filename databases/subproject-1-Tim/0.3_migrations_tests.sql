\set ON_ERROR_STOP on

BEGIN;
\i ./tests/moviedb-port-test.sql
ROLLBACK;