-- Deploy app:0000000002-data to pg

BEGIN;

set search_path = settings, pg_catalog, public;

insert into secrets (key, value) values ('jwt_lifetime', 3600);
insert into secrets (key, value) values ('auth.default-role', 'webuser');
insert into secrets (key, value) values ('auth.data-schema', 'data');
insert into secrets (key, value) values ('auth.api-schema', 'api');
insert into secrets (key, value) values ('jwt_secret', gen_random_uuid());

COMMIT;
