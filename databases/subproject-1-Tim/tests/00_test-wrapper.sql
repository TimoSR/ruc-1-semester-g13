\set ON_ERROR_STOP on

BEGIN;
--\i moviedb-test.sql
\i profile-test.sql
ROLLBACK;