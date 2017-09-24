select settings.set('auth.data-schema', current_schema);

--Extension
create extension if not exists "uuid-ossp";

-- Table
create table "user" (
	id						uuid not null default uuid_generate_v1mc(),
	email				  text,
	"password"         text,
	phone_number   text,
	"role"                 user_role not null default settings.get('auth.default-role')::user_role,
	created_at			timestamp default now(),
	updated_at		   timestamp default now(),

	constraint		   user_pk primary key(id),
	constraint		   user_email_uk unique(email) not deferrable initially immediate,
	constraint		   user_phone_number_uk unique(phone_number) not deferrable initially immediate,
	constraint 		   check_email_or_phone check (
		phone_number is not null and email is null
		or
		phone_number is null and email ~* '^.+@.+\..+$'
        or
		phone_number is not null and email ~* '^.+@.+\..+$'
	),
	constraint 		  check_password check (
		email is null and password is null
		or
		email is not null and password is not null
	)
);

create trigger user_encrypt_pass_trigger
before insert or update on "user"
for each row
execute procedure auth.encrypt_pass();
