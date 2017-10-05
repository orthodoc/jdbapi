START TRANSACTION;

CREATE SCHEMA utilities;

CREATE EXTENSION "uuid-ossp" SCHEMA data;

SET search_path = api, pg_catalog;

DROP FUNCTION signup(name text, email text, password text);

ALTER TYPE "user"
	DROP ATTRIBUTE name,
	ALTER ATTRIBUTE id TYPE uuid /* TYPE change - table: user original: integer new: uuid */;

CREATE OR REPLACE FUNCTION login(email text, password text) RETURNS session
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
    usr record;
    result record;
begin
    EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.data-schema')) || ', public';
    select row_to_json(u.*) as j into usr
        from "user" as u
        where u.email = login.email and u.password = crypt(login.password, u.password);

    if not found then
        RESET search_path;
        raise exception 'invalid email/password or phone number';
    else
        EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.api-schema')) || ', public';
        result = (
            row_to_json(json_populate_record(null::"user", usr.j)),
            auth.sign_jwt(auth.get_jwt_payload(usr.j))
        );
        RESET search_path;
        return result;
    end if;
end
$$;

CREATE OR REPLACE FUNCTION signup(email text, password text) RETURNS session
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
    usr record;
    result record;
begin
	EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.data-schema')) || ', public';                 
    insert into "user" as u
        (email, password) values
        (signup.email, signup.password)
        returning row_to_json(u.*) as j into usr;

    -- invalidate null registrations
    if usr is null then
        raise invalid_password using message = 'invalid email or password';
    end if;

    EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.api-schema')) || ', public';
    result := (
        row_to_json(json_populate_record(null::"user", usr.j)),
        auth.sign_jwt(auth.get_jwt_payload(usr.j))
    );


    RESET search_path;
    return result;
end
$$;

SET search_path = auth, pg_catalog;

CREATE OR REPLACE FUNCTION set_auth_endpoints_privileges("schema" text, anonymous text, roles text[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare r record;
begin
  execute 'grant execute on function ' || quote_ident(schema) || '.login(text,text) to ' || quote_ident(anonymous);
  execute 'grant execute on function ' || quote_ident(schema) || '.signup(text,text) to ' || quote_ident(anonymous);
  for r in
     select unnest(roles) as role
  loop
     execute 'grant execute on function ' || quote_ident(schema) || '.me() to ' || quote_ident(r.role);
     execute 'grant execute on function ' || quote_ident(schema) || '.login(text,text) to ' || quote_ident(r.role);
     execute 'grant execute on function ' || quote_ident(schema) || '.refresh_token() to ' || quote_ident(r.role);
  end loop;
end;
$$;

SET search_path = data, pg_catalog;

ALTER TABLE "user"
	DROP CONSTRAINT user_pkey;

ALTER TABLE "user"
	DROP CONSTRAINT user_email_check;

ALTER TABLE "user"
	DROP CONSTRAINT user_name_check;

ALTER TABLE "user"
	DROP CONSTRAINT user_email_key;

DROP SEQUENCE user_id_seq;

ALTER TABLE todo
	ALTER COLUMN owner_id TYPE uuid /* TYPE change - table: todo original: integer new: uuid */;

ALTER TABLE "user"
	DROP COLUMN name,
	ADD COLUMN created_at timestamp without time zone DEFAULT now(),
	ADD COLUMN updated_at timestamp without time zone DEFAULT now(),
	ALTER COLUMN id TYPE uuid /* TYPE change - table: user original: integer new: uuid */,
	ALTER COLUMN id SET DEFAULT uuid_generate_v1mc();

ALTER TABLE "user"
	ADD CONSTRAINT user_pk PRIMARY KEY (id);

ALTER TABLE "user"
	ADD CONSTRAINT user_email_uk UNIQUE (email);

SET search_path = request, pg_catalog;

CREATE OR REPLACE FUNCTION user_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
    select 
    case request.jwt_claim('user_id') 
    when '' then null
    else request.jwt_claim('user_id')::uuid
	end
$$;

SET search_path = utilities, pg_catalog;

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    new.updated_at := current_timestamp;
end;
$$;

COMMIT TRANSACTION;
