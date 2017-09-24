\echo # Loading update schema
drop schema if exists utilities cascade;
create schema utilities;

create or replace function utilities.set_updated_at() returns trigger as
$$
begin
    new.updated_at := current_timestamp;
end;
$$ language plpgsql;