create or replace function 
signup(
        email text,
        password text,
        role text default quote_ident(settings.get('auth.default-role'))
    )
    returns session as $$
declare
    usr record;
    result record;
begin
	EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.data-schema')) || ', public';
    if signup.password <> ' ' then
        insert into "user" as u
            (email, password, role) values
            (signup.email, signup.password, signup.role::user_role)
            returning row_to_json(u.*) as j into usr;
    else
        raise invalid_password using message = 'invalid password';
    end if;

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
$$ security definer language plpgsql;

revoke all privileges on function signup(text, text, text) from public;
