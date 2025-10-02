\i 01_schemas.sql
\i 02_moviedb_framework.sql
\i 03_profile_framework.sql

BEGIN TRANSACTION;
\i ./tests/profile-test.sql
ROLLBACK TRANSACTION;