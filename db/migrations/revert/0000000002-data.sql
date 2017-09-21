-- Revert app:0000000002-data from pg

BEGIN;

set search_path = settings, pg_catalog;
truncate secrets;

COMMIT;
