-- Deploy app:0000000002-data to pg

BEGIN;

set search_path = settings, pg_catalog, public;

copy secrets (key, value) from stdin;
jwt_lifetime  3600
auth.default-role  webuser
auth.data-schema  data
auth.api-schema  api
\.

insert into secrets (key, value) values ('jwt_secret', gen_random_uuid());

COMMIT;
