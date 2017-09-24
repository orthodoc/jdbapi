create or replace function 
signup(
        email text default null,
        password text default null,
        phone_number text default null
    )
    returns session as $$
declare
    usr record;
    result record;
begin
	EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.data-schema')) || ', public';
    -- Email and phone number
    if email is not null and phone_number is not null then
        insert into "user" as u
            (email, password, phone_number) values
            (signup.email, signup.password, signup.phone_number)
            returning row_to_json(u.*) as j into usr;
    end if;
    -- Only phone number
    if email is null and phone_number is not null then
        insert into "user" as u
            (phone_number) values
            (signup.phone_number)
            returning row_to_json(u.*) as j into usr;
    end if;
    --Only email
    if email is not null and phone_number is null then
        insert into "user" as u
            (email, password) values
            (signup.email, signup.password)
            returning row_to_json(u.*) as j into usr;
    end if;

    -- invalidate null registrations
    if usr is null then
        raise invalid_password using message = 'invalid email/password or phone number';
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
