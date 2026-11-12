drop table if exists stg_enrollments;


create table stg_enrollments as
select * from raw_enrollments;




alter table stg_enrollments
	add column row_id serial;


