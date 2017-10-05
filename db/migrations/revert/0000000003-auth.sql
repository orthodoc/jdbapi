START TRANSACTION;

DROP SCHEMA utilities CASCADE;

DROP EXTENSION "uuid-ossp" CASCADE;

SET search_path = api, pg_catalog;

DROP FUNCTION signup(email text, password text);

ALTER TYPE "user"
	ADD ATTRIBUTE name text,
	ALTER ATTRIBUTE id TYPE integer /* TYPE change - table: user original: uuid new: integer */;

CREATE OR REPLACE FUNCTION login(email text, password text) RETURNS session
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
declare
    usr record;
    result record;
begin
    EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.data-schema')) || ', public';

    select row_to_json(u.*) as j into usr
    from "user" as u
    where u.email = $1 and u.password = crypt($2, u.password);
    

    if not found then
        RESET search_path;
        raise exception 'invalid email/password';
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
$_$;

CREATE OR REPLACE FUNCTION signup(name text, email text, password text) RETURNS session
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
declare
    usr record;
    result record;
begin
	EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.data-schema')) || ', public';
    insert into "user" as u
    (name, email, password) values
    ($1, $2, $3)
    returning row_to_json(u.*) as j into usr;

    EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.api-schema')) || ', public';
    result := (
        row_to_json(json_populate_record(null::"user", usr.j)),
        auth.sign_jwt(auth.get_jwt_payload(usr.j))
    );


    RESET search_path;
    return result;
end
$_$;

SET search_path = auth, pg_catalog;

CREATE OR REPLACE FUNCTION set_auth_endpoints_privileges("schema" text, anonymous text, roles text[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare r record;
begin
  execute 'grant execute on function ' || quote_ident(schema) || '.login(text,text) to ' || quote_ident(anonymous);
  execute 'grant execute on function ' || quote_ident(schema) || '.signup(text,text,text) to ' || quote_ident(anonymous);
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
	DROP CONSTRAINT user_pk;

ALTER TABLE "user"
	DROP CONSTRAINT user_email_uk;

CREATE SEQUENCE user_id_seq
	START WITH 1
	INCREMENT BY 1
	NO MAXVALUE
	NO MINVALUE
	CACHE 1;

ALTER TABLE todo
	ALTER COLUMN owner_id TYPE integer /* TYPE change - table: todo original: uuid new: integer */;

ALTER TABLE "user"
	DROP COLUMN created_at,
	DROP COLUMN updated_at,
	ADD COLUMN name text NOT NULL,
	ALTER COLUMN id TYPE integer /* TYPE change - table: user original: uuid new: integer */,
	ALTER COLUMN id SET DEFAULT nextval('user_id_seq'::regclass);

ALTER SEQUENCE user_id_seq
	OWNED BY "user".id;

ALTER TABLE "user"
	ADD CONSTRAINT user_pkey PRIMARY KEY (id);

ALTER TABLE "user"
	ADD CONSTRAINT user_email_check CHECK ((email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'::text));

ALTER TABLE "user"
	ADD CONSTRAINT user_name_check CHECK ((length(name) > 2));

ALTER TABLE "user"
	ADD CONSTRAINT user_email_key UNIQUE (email);

SET search_path = request, pg_catalog;

CREATE OR REPLACE FUNCTION user_id() RETURNS integer
    LANGUAGE sql STABLE
    AS $$
    select 
    case request.jwt_claim('user_id') 
    when '' then 0
    else request.jwt_claim('user_id')::int
	end
$$;

COMMIT TRANSACTION;
