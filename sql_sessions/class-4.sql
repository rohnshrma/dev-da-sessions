update stg_enrollments
set enrollment_id = trim(REGEXP_REPLACE(enrollment_id , '\s+' , ' ', 'g')),
	full_name = trim(REGEXP_REPLACE(full_name , '\s+' , ' ', 'g')),
	gender = trim(gender),
	email = trim(email),
	phone = trim(phone),
	age = trim(age),
	enroll_date = trim(enroll_date),
	fee_paid = trim(fee_paid),
	status = trim(status),
	rating = trim(rating),
	city = trim(REGEXP_REPLACE(city , '\s+' , ' ', 'g')),
	course = trim(REGEXP_REPLACE(course , '\s+' , ' ', 'g')),
	payment_mode = trim(REGEXP_REPLACE(payment_mode , '\s+' , ' ', 'g'));



	select * from stg_enrollments
	where full_name <> trim(full_name);