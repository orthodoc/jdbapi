
create or replace function
    login(
        email text default null,
        password text default null,
        phone_number text default null
    ) returns session as $$
declare
    usr record;
    result record;
begin
    EXECUTE 'SET search_path TO ' || quote_ident(settings.get('auth.data-schema')) || ', public';

    -- only email
    if email is not null and phone_number is null then
        select row_to_json(u.*) as j into usr
            from "user" as u
            where u.email = login.email and u.password = crypt(login.password, u.password);
    end if;

    -- only phone number
    if email is null and phone_number is not null then
        select row_to_json(u.*) as j into usr
            from "user" as u
            where u.phone_number = login.phone_number;
    end if;

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
$$ security definer language plpgsql;
-- by default all functions are accessible to the public, we need to remove that and define our specific access rules
revoke all privileges on function login(text, text, text) from public;