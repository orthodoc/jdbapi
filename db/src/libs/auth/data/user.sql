select settings.set('auth.data-schema', current_schema);

--Extension
create extension if not exists "uuid-ossp";

-- Table
create table "user" (
	id						uuid not null default uuid_generate_v1mc(),
	email				  text not null,
	"password"         text not null,
	"role"                 user_role not null default settings.get('auth.default-role')::user_role,
	created_at			timestamp default now(),
	updated_at		   timestamp default now(),

	constraint		   user_pk primary key(id),
	constraint		   user_email_uk unique(email) not deferrable initially immediate
);

create trigger user_encrypt_pass_trigger
before insert or update on "user"
for each row
execute procedure auth.encrypt_pass();
