\set ON_ERROR_STOP on

BEGIN;
\i ./tests/profile-test.sql
\i ./tests/movie-db-tests.sql
ROLLBACK;