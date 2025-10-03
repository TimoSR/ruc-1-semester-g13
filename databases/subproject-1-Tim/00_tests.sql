\set ON_ERROR_STOP on

BEGIN;
\i ./tests/moviedb-test.sql
\i ./tests/profile-test.sql
ROLLBACK;