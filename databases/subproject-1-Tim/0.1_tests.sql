\set ON_ERROR_STOP on

BEGIN;
\i ./tests/profile-test.sql
ROLLBACK;