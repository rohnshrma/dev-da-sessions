create or replace function nullify(val text)
returns text
language sql
immutable
as $$
	select case 
 	when val is null then null
	when lower(trim(val)) in ('' , 'na' , 'n/a' , 'null', 'none', 
								'unknown', 'tbd', '-' , 'not sure')
			then null
	else val
	end;
$$;



update stg_enrollments
set enrollment_id 	= nullify(enrollment_id),
	full_name = nullify(full_name),
	gender = nullify(gender),
	age = nullify(age),
	email = nullify(email),
	phone = nullify(phone),
	city = nullify(city),
	course = nullify(course),
	enroll_date = nullify(enroll_date),
	fee_paid = nullify(fee_paid),
	payment_mode = nullify(payment_mode),
	status = nullify(status),
	rating = nullify(rating);



select count(*) filter (where email is not null) as missing_emails 
from stg_enrollments;