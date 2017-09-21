--
-- PostgreSQL database cluster dump
--

SET default_transaction_read_only = off;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

--
-- Roles
--

CREATE ROLE anonymous;
CREATE ROLE api;
CREATE ROLE webuser;


--
-- Role memberships
--

GRANT anonymous TO authenticator;
GRANT api TO current_user;
GRANT webuser TO authenticator;


--
-- PostgreSQL database cluster dump complete
--


--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.5
-- Dumped by pg_dump version 9.6.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: api; Type: SCHEMA; Schema: -; Owner: superuser
--

CREATE SCHEMA api;



--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: superuser
--

CREATE SCHEMA auth;



--
-- Name: data; Type: SCHEMA; Schema: -; Owner: superuser
--

CREATE SCHEMA data;



--
-- Name: pgjwt; Type: SCHEMA; Schema: -; Owner: superuser
--

CREATE SCHEMA pgjwt;



--
-- Name: rabbitmq; Type: SCHEMA; Schema: -; Owner: superuser
--

CREATE SCHEMA rabbitmq;



--
-- Name: request; Type: SCHEMA; Schema: -; Owner: superuser
--

CREATE SCHEMA request;



--
-- Name: settings; Type: SCHEMA; Schema: -; Owner: superuser
--

CREATE SCHEMA settings;



--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--



--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--



SET search_path = api, pg_catalog;

--
-- Name: session; Type: TYPE; Schema: api; Owner: superuser
--

CREATE TYPE session AS (
	me json,
	token text
);



--
-- Name: user; Type: TYPE; Schema: api; Owner: superuser
--

CREATE TYPE "user" AS (
	id integer,
	name text,
	email text,
	role text
);



SET search_path = data, pg_catalog;

--
-- Name: user_role; Type: TYPE; Schema: data; Owner: superuser
--

CREATE TYPE user_role AS ENUM (
    'webuser'
);



SET search_path = public, pg_catalog;

--
-- Name: _time_trial_type; Type: TYPE; Schema: public; Owner: superuser
--

CREATE TYPE _time_trial_type AS (
	a_time numeric
);



SET search_path = api, pg_catalog;

--
-- Name: login(text, text); Type: FUNCTION; Schema: api; Owner: superuser
--

CREATE FUNCTION login(email text, password text) RETURNS session
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



--
-- Name: me(); Type: FUNCTION; Schema: api; Owner: superuser
--

CREATE FUNCTION me() RETURNS "user"
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
	usr record;
begin
	EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.data-schema')) || ', public';
	select row_to_json(u.*) as j into usr
    from "user" as u
    where id = request.user_id();

    EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.api-schema')) || ', public';
	select json_populate_record(null::"user", usr.j) as r into usr;

	RESET search_path;
	return usr.r;
end
$$;



--
-- Name: refresh_token(); Type: FUNCTION; Schema: api; Owner: superuser
--

CREATE FUNCTION refresh_token() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
	usr record;
	token text;
begin
    EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.data-schema')) || ', public';
    select row_to_json(u.*) as j into usr
    from "user" as u
    where u.id = request.user_id();

    RESET search_path;
    
    if not found then
    	raise exception 'user not found';
    else
    	select auth.sign_jwt(auth.get_jwt_payload(usr.j))
    	into token;
    	return token;
    end if;
end
$$;



--
-- Name: signup(text, text, text); Type: FUNCTION; Schema: api; Owner: superuser
--

CREATE FUNCTION signup(name text, email text, password text) RETURNS session
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

--
-- Name: encrypt_pass(); Type: FUNCTION; Schema: auth; Owner: superuser
--

CREATE FUNCTION encrypt_pass() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if new.password is not null then
  	new.password = crypt(new.password, gen_salt('bf'));
  end if;
  return new;
end
$$;



--
-- Name: get_jwt_payload(json); Type: FUNCTION; Schema: auth; Owner: superuser
--

CREATE FUNCTION get_jwt_payload(json) RETURNS json
    LANGUAGE sql STABLE
    AS $_$
    select json_build_object(
                'role', $1->'role',
                'user_id', $1->'id',
                'exp', extract(epoch from now())::integer + settings.get('jwt_lifetime')::int -- token expires in 1 hour
            )
$_$;



--
-- Name: set_auth_endpoints_privileges(text, text, text[]); Type: FUNCTION; Schema: auth; Owner: superuser
--

CREATE FUNCTION set_auth_endpoints_privileges(schema text, anonymous text, roles text[]) RETURNS void
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



--
-- Name: sign_jwt(json); Type: FUNCTION; Schema: auth; Owner: superuser
--

CREATE FUNCTION sign_jwt(json) RETURNS text
    LANGUAGE sql STABLE
    AS $_$
    select pgjwt.sign($1, settings.get('jwt_secret'))
$_$;



SET search_path = pgjwt, pg_catalog;

--
-- Name: algorithm_sign(text, text, text); Type: FUNCTION; Schema: pgjwt; Owner: superuser
--

CREATE FUNCTION algorithm_sign(signables text, secret text, algorithm text) RETURNS text
    LANGUAGE sql
    AS $$
WITH
  alg AS (
    SELECT CASE
      WHEN algorithm = 'HS256' THEN 'sha256'
      WHEN algorithm = 'HS384' THEN 'sha384'
      WHEN algorithm = 'HS512' THEN 'sha512'
      ELSE '' END)  -- hmac throws error
SELECT pgjwt.url_encode(hmac(signables, secret, (select * FROM alg)));
$$;



--
-- Name: sign(json, text, text); Type: FUNCTION; Schema: pgjwt; Owner: superuser
--

CREATE FUNCTION sign(payload json, secret text, algorithm text DEFAULT 'HS256'::text) RETURNS text
    LANGUAGE sql
    AS $$
WITH
  header AS (
    SELECT pgjwt.url_encode(convert_to('{"alg":"' || algorithm || '","typ":"JWT"}', 'utf8'))
    ),
  payload AS (
    SELECT pgjwt.url_encode(convert_to(payload::text, 'utf8'))
    ),
  signables AS (
    SELECT (SELECT * FROM header) || '.' || (SELECT * FROM payload)
    )
SELECT
    (SELECT * FROM signables)
    || '.' ||
    pgjwt.algorithm_sign((SELECT * FROM signables), secret, algorithm);
$$;



--
-- Name: url_decode(text); Type: FUNCTION; Schema: pgjwt; Owner: superuser
--

CREATE FUNCTION url_decode(data text) RETURNS bytea
    LANGUAGE sql
    AS $$
WITH t AS (SELECT translate(data, '-_', '+/')),
     rem AS (SELECT length((SELECT * FROM t)) % 4) -- compute padding size
    SELECT decode(
        (SELECT * FROM t) ||
        CASE WHEN (SELECT * FROM rem) > 0
           THEN repeat('=', (4 - (SELECT * FROM rem)))
           ELSE '' END,
    'base64');
$$;



--
-- Name: url_encode(bytea); Type: FUNCTION; Schema: pgjwt; Owner: superuser
--

CREATE FUNCTION url_encode(data bytea) RETURNS text
    LANGUAGE sql
    AS $$
    SELECT translate(encode(data, 'base64'), E'+/=\n', '-_');
$$;



--
-- Name: verify(text, text, text); Type: FUNCTION; Schema: pgjwt; Owner: superuser
--

CREATE FUNCTION verify(token text, secret text, algorithm text DEFAULT 'HS256'::text) RETURNS TABLE(header json, payload json, valid boolean)
    LANGUAGE sql
    AS $$
  SELECT
    convert_from(pgjwt.url_decode(r[1]), 'utf8')::json AS header,
    convert_from(pgjwt.url_decode(r[2]), 'utf8')::json AS payload,
    r[3] = pgjwt.algorithm_sign(r[1] || '.' || r[2], secret, algorithm) AS valid
  FROM regexp_split_to_array(token, '\.') r;
$$;



SET search_path = rabbitmq, pg_catalog;

--
-- Name: on_row_change(); Type: FUNCTION; Schema: rabbitmq; Owner: superuser
--

CREATE FUNCTION on_row_change() RETURNS trigger
    LANGUAGE plpgsql STABLE
    AS $$
  declare
    routing_key text;
    row record;
  begin
    routing_key := 'row_change'
                   '.table-'::text || TG_TABLE_NAME::text || 
                   '.event-'::text || TG_OP::text;
    if (TG_OP = 'DELETE') then
        row := old;
    elsif (TG_OP = 'UPDATE') then
        row := new;
    elsif (TG_OP = 'INSERT') then
        row := new;
    end if;
    perform rabbitmq.send_message('events', routing_key, row_to_json(row)::text);
    return null;
  end;
$$;



--
-- Name: send_message(text, text, text); Type: FUNCTION; Schema: rabbitmq; Owner: superuser
--

CREATE FUNCTION send_message(channel text, routing_key text, message text) RETURNS void
    LANGUAGE sql STABLE
    AS $$
     
  select  pg_notify(
    channel,  
    routing_key || '|' || message
  );
$$;



SET search_path = request, pg_catalog;

--
-- Name: cookie(text); Type: FUNCTION; Schema: request; Owner: superuser
--

CREATE FUNCTION cookie(c text) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    select request.env_var('request.cookie.' || c);
$$;



--
-- Name: env_var(text); Type: FUNCTION; Schema: request; Owner: superuser
--

CREATE FUNCTION env_var(v text) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    select current_setting(v, true);
$$;



--
-- Name: header(text); Type: FUNCTION; Schema: request; Owner: superuser
--

CREATE FUNCTION header(h text) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    select request.env_var('request.header.' || h);
$$;



--
-- Name: jwt_claim(text); Type: FUNCTION; Schema: request; Owner: superuser
--

CREATE FUNCTION jwt_claim(c text) RETURNS text
    LANGUAGE sql STABLE
    AS $$
    select request.env_var('request.jwt.claim.' || c);
$$;



--
-- Name: user_id(); Type: FUNCTION; Schema: request; Owner: superuser
--

CREATE FUNCTION user_id() RETURNS integer
    LANGUAGE sql STABLE
    AS $$
    select 
    case request.jwt_claim('user_id') 
    when '' then 0
    else request.jwt_claim('user_id')::int
	end
$$;



--
-- Name: user_role(); Type: FUNCTION; Schema: request; Owner: superuser
--

CREATE FUNCTION user_role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
    select request.jwt_claim('role')::text;
$$;



SET search_path = settings, pg_catalog;

--
-- Name: get(text); Type: FUNCTION; Schema: settings; Owner: superuser
--

CREATE FUNCTION get(text) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    AS $_$
    select value from settings.secrets where key = $1
$_$;



--
-- Name: set(text, text); Type: FUNCTION; Schema: settings; Owner: superuser
--

CREATE FUNCTION set(text, text) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    AS $_$
	insert into settings.secrets (key, value)
	values ($1, $2)
	on conflict (key) do update
	set value = $2;
$_$;



SET search_path = data, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: todo; Type: TABLE; Schema: data; Owner: superuser
--

CREATE TABLE todo (
    id integer NOT NULL,
    todo text NOT NULL,
    private boolean DEFAULT true,
    owner_id integer DEFAULT request.user_id()
);



SET search_path = api, pg_catalog;

--
-- Name: todos; Type: VIEW; Schema: api; Owner: api
--

CREATE VIEW todos AS
 SELECT todo.id,
    todo.todo,
    todo.private,
    (todo.owner_id = request.user_id()) AS mine
   FROM data.todo;


ALTER TABLE todos OWNER TO api;

SET search_path = data, pg_catalog;

--
-- Name: todo_id_seq; Type: SEQUENCE; Schema: data; Owner: superuser
--

CREATE SEQUENCE todo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



--
-- Name: todo_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: superuser
--

ALTER SEQUENCE todo_id_seq OWNED BY todo.id;


--
-- Name: user; Type: TABLE; Schema: data; Owner: superuser
--

CREATE TABLE "user" (
    id integer NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    password text NOT NULL,
    role user_role DEFAULT (settings.get('auth.default-role'::text))::user_role NOT NULL,
    CONSTRAINT user_email_check CHECK ((email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'::text)),
    CONSTRAINT user_name_check CHECK ((length(name) > 2))
);



--
-- Name: user_id_seq; Type: SEQUENCE; Schema: data; Owner: superuser
--

CREATE SEQUENCE user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;



--
-- Name: user_id_seq; Type: SEQUENCE OWNED BY; Schema: data; Owner: superuser
--

ALTER SEQUENCE user_id_seq OWNED BY "user".id;


SET search_path = settings, pg_catalog;

--
-- Name: secrets; Type: TABLE; Schema: settings; Owner: superuser
--

CREATE TABLE secrets (
    key text NOT NULL,
    value text NOT NULL
);



SET search_path = data, pg_catalog;

--
-- Name: todo id; Type: DEFAULT; Schema: data; Owner: superuser
--

ALTER TABLE ONLY todo ALTER COLUMN id SET DEFAULT nextval('todo_id_seq'::regclass);


--
-- Name: user id; Type: DEFAULT; Schema: data; Owner: superuser
--

ALTER TABLE ONLY "user" ALTER COLUMN id SET DEFAULT nextval('user_id_seq'::regclass);


--
-- Name: todo todo_pkey; Type: CONSTRAINT; Schema: data; Owner: superuser
--

ALTER TABLE ONLY todo
    ADD CONSTRAINT todo_pkey PRIMARY KEY (id);


--
-- Name: user user_email_key; Type: CONSTRAINT; Schema: data; Owner: superuser
--

ALTER TABLE ONLY "user"
    ADD CONSTRAINT user_email_key UNIQUE (email);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: data; Owner: superuser
--

ALTER TABLE ONLY "user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


SET search_path = settings, pg_catalog;

--
-- Name: secrets secrets_pkey; Type: CONSTRAINT; Schema: settings; Owner: superuser
--

ALTER TABLE ONLY secrets
    ADD CONSTRAINT secrets_pkey PRIMARY KEY (key);


SET search_path = data, pg_catalog;

--
-- Name: todo send_change_event; Type: TRIGGER; Schema: data; Owner: superuser
--

CREATE TRIGGER send_change_event AFTER INSERT OR DELETE OR UPDATE ON todo FOR EACH ROW EXECUTE PROCEDURE rabbitmq.on_row_change();


--
-- Name: user user_encrypt_pass_trigger; Type: TRIGGER; Schema: data; Owner: superuser
--

CREATE TRIGGER user_encrypt_pass_trigger BEFORE INSERT OR UPDATE ON "user" FOR EACH ROW EXECUTE PROCEDURE auth.encrypt_pass();


--
-- Name: todo todo_owner_id_fkey; Type: FK CONSTRAINT; Schema: data; Owner: superuser
--

ALTER TABLE ONLY todo
    ADD CONSTRAINT todo_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES "user"(id);


--
-- Name: todo; Type: ROW SECURITY; Schema: data; Owner: superuser
--

ALTER TABLE todo ENABLE ROW LEVEL SECURITY;

--
-- Name: todo todo_access_policy; Type: POLICY; Schema: data; Owner: superuser
--

CREATE POLICY todo_access_policy ON todo FOR ALL TO api USING ((((request.user_role() = 'webuser'::text) AND (request.user_id() = owner_id)) OR (private = false))) WITH CHECK (((request.user_role() = 'webuser'::text) AND (request.user_id() = owner_id)));


--
-- Name: api; Type: ACL; Schema: -; Owner: superuser
--

GRANT USAGE ON SCHEMA api TO anonymous;
GRANT USAGE ON SCHEMA api TO webuser;


--
-- Name: rabbitmq; Type: ACL; Schema: -; Owner: superuser
--

GRANT USAGE ON SCHEMA rabbitmq TO PUBLIC;


--
-- Name: request; Type: ACL; Schema: -; Owner: superuser
--

GRANT USAGE ON SCHEMA request TO PUBLIC;


SET search_path = api, pg_catalog;

--
-- Name: login(text, text); Type: ACL; Schema: api; Owner: superuser
--

REVOKE ALL ON FUNCTION login(email text, password text) FROM PUBLIC;
GRANT ALL ON FUNCTION login(email text, password text) TO anonymous;
GRANT ALL ON FUNCTION login(email text, password text) TO webuser;


--
-- Name: me(); Type: ACL; Schema: api; Owner: superuser
--

REVOKE ALL ON FUNCTION me() FROM PUBLIC;
GRANT ALL ON FUNCTION me() TO webuser;


--
-- Name: refresh_token(); Type: ACL; Schema: api; Owner: superuser
--

REVOKE ALL ON FUNCTION refresh_token() FROM PUBLIC;
GRANT ALL ON FUNCTION refresh_token() TO webuser;


--
-- Name: signup(text, text, text); Type: ACL; Schema: api; Owner: superuser
--

REVOKE ALL ON FUNCTION signup(name text, email text, password text) FROM PUBLIC;
GRANT ALL ON FUNCTION signup(name text, email text, password text) TO anonymous;


SET search_path = data, pg_catalog;

--
-- Name: todo; Type: ACL; Schema: data; Owner: superuser
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE todo TO api;


SET search_path = api, pg_catalog;

--
-- Name: todos; Type: ACL; Schema: api; Owner: api
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE todos TO webuser;


--
-- Name: todos.id; Type: ACL; Schema: api; Owner: api
--

GRANT SELECT(id) ON TABLE todos TO anonymous;


--
-- Name: todos.todo; Type: ACL; Schema: api; Owner: api
--

GRANT SELECT(todo) ON TABLE todos TO anonymous;


SET search_path = data, pg_catalog;

--
-- Name: todo_id_seq; Type: ACL; Schema: data; Owner: superuser
--

GRANT USAGE ON SEQUENCE todo_id_seq TO webuser;


--
-- PostgreSQL database dump complete
--

