select settings.set('auth.api-schema', current_schema);
create type "user" as (id uuid, email text, phone_number text, role text);
