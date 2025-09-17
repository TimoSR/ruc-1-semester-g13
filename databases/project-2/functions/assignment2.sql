-- Q1
-- count number of courses attended by given student id
create or replace function course_count1(student_id varchar(5))
    returns integer
    language plpgsql as $$
    declare c_count integer;
    begin
        select count(*) into c_count
        from takes
        where takes.id = student_id;
        return c_count;
    end;
    $$;

-- test queries:
select course_count1('12345');
select id,course_count1(id) from student;

-- Q2
-- count number of course attended by given student id and department name
create or replace function course_count_2(student_id varchar(5), d_name varchar(20))
    returns integer
    language plpgsql as $$
    declare c_count integer;
    begin
        select count(*) into c_count
        from takes t join course c
            on t.course_id = c.course_id
        where t.id = student_id and c.dept_name = d_name;
        return c_count;
    end;
    $$;

-- test queries:
select course_count_2('12345','Comp. Sci.');
select id,name,course_count_2(id,'Comp. Sci.') from student;

-- Q3
-- count number of courses attended by given student id with optional department name
create or replace function course_count(student_id varchar(5), d_name varchar(20) default null)
    returns integer
    language plpgsql as $$
    declare c_count integer;
    begin
        if d_name is null then
            select count(*) into c_count
            from takes
            where takes.id = student_id;
        else
            select count(*) into c_count
            from takes natural join course
            where takes.id = student_id and course.dept_name = d_name;
        end if;
        return c_count;
    end;
    $$;
-- explain your solution:
-- d_name, the parameter for the department name, has a default value: 'null'.
-- This means that when the function is called with only one parameter, the code will assume it's the student_id and it doensn't require a second parameter.
-- If the second parameter is not null (or default), it will be considered for the query result.

-- test queries:
select course_count('12345');
select course_count('12345','Comp. Sci.');
select id,name,course_count(id,'Comp. Sci.') from student;

-- Q4
-- list department activities (instructor, course, semester, year) for given department name
create or replace function department_activities(d_name varchar(20))
    returns table(
        instructor_name varchar(20),
        course_title varchar(50),
        semester varchar(6),
        year numeric(4,0))
    language plpgsql as $$
    begin
        return query
        select i.name as instructor_name, c.title as course_title, t.semester, t.year
        from instructor i
        join teaches t on i.id = t.id
        join course c on t.course_id = c.course_id
        where i.dept_name = d_name;
    end;
    $$;

-- test queries:
SELECT department_activities('Comp. Sci.');
SELECT * from department_activities('Comp. Sci.'); -- correct query to return a table

-- Q5
-- list activities (department, instructor, course, semester, year) for given department name or building name
create or replace function activities(db_name varchar(20))
    returns table(
        dept_name varchar(20),
        instructor_name varchar(20),
        course_title varchar(50),
        semester varchar(6),
        year numeric(4,0))
    language plpgsql as $$
    begin
        -- with department name
        if exists (select 1 from department d where d.dept_name = db_name) then
            return query
            select i.dept_name, i.name as instructor_name, c.title as course_title, t.semester, t.year
            from instructor i
            join teaches t on i.id = t.id
            join course c on t.course_id = c.course_id
            where i.dept_name = db_name;
        -- with building name
        elsif exists (select 1 from department d where d.building = db_name) then
            return query
            select i.dept_name, i.name as instructor_name, c.title as course_title, t.semester, t.year
            from instructor i
            join teaches t on i.id = t.id
            join department d on i.dept_name = d.dept_name
            join course c on t.course_id = c.course_id
            where d.building = db_name;
        end if;
    end;
    $$;
-- test queries:
SELECT activities('Comp. Sci.');
SELECT * from activities('Comp. Sci.'); -- correct query to return a table
SELECT activities('Watson');
SELECT * from activities('Watson'); -- correct query to return a table

-- Q6
-- return instructors who taught the courses taken by given student 
-- use cursor for to loop through the query result and assemble the string
create or replace function followed_courses_by(s_name varchar(20))
    returns text
    language plpgsql as $$
    declare 
        i_list text := '';
        instr_name instructor.name%TYPE;
        cur1 cursor for 
            with courses_attended as (
                    select course_id, sec_id, semester, year
                    from takes t
                    join student s on t.id = s.id
                    where s.name = s_name
                )
                select distinct i.name
                from instructor i
                join teaches t on i.id = t.id
                join courses_attended ca
                    on ca.course_id = t.course_id
                    and ca.sec_id = t.sec_id
                    and ca.semester = t.semester
                    and ca.year = t.year;
    begin
        open cur1;            
        loop
            fetch cur1 into instr_name;
            exit when not found;

            if i_list = '' then
                i_list := instr_name;
            else
                i_list := i_list || ', ' || instr_name;
            end if;
        end loop;
        close cur1;

        return i_list;
    end;
    $$;
-- test queries:
select followed_courses_by('Shankar');
select name, followed_courses_by(name) from student;

-- Q7
-- rewrite q6 using for loop
create or replace function followed_courses_by(s_name varchar(20))
    returns text
    language plpgsql as $$
    declare 
        i_list text := '';
        instr_name instructor.name%TYPE;
                 
    begin
        for instr_name in
        with courses_attended as (
                select course_id, sec_id, semester, year
                from takes t
                join student s on t.id = s.id
                where s.name = s_name
            ),
        instructors_for_courses as (
                select distinct i.name
                from instructor i
                join teaches t on i.id = t.id
                join courses_attended ca
                    on ca.course_id = t.course_id
                    and ca.sec_id = t.sec_id
                    and ca.semester = t.semester
                    and ca.year = t.year
            )
        select * from instructors_for_courses
        loop
            if i_list = '' then
                i_list := instr_name;
            else
                i_list := i_list || ', ' || instr_name;
            end if;
        end loop;

        return i_list;
    end;
    $$;
-- test queries:
select followed_courses_by('Shankar');
select name, followed_courses_by(name) from student;

-- Q8
-- rewrite q7 using string_agg()
create or replace function followed_courses_by(s_name varchar(20))
    returns text
    language plpgsql as $$
    declare
        i_list text;

    begin
        with courses_attended as (
            select course_id, sec_id, semester, year
            from takes t
            join student s on t.id = s.id
            where s.name = s_name
        )
        select string_agg(distinct i.name, ', ')
        into i_list
        from instructor i
        join teaches t on i.id = t.id
        join courses_attended ca
            on ca.course_id = t.course_id
            and ca.sec_id = t.sec_id
            and ca.semester = t.semester
            and ca.year = t.year;
        
        return i_list;
    end;
    $$;
-- test queries:
select followed_courses_by('Shankar');
select name, followed_courses_by(name) from student;

-- Q9
-- return instructors + advisors who taught courses taken by given student
create or replace function taught_by(s_name varchar(20))
    returns text
    language plpgsql as $$
    declare
        ia_list text;

    begin
        with courses_attended as (
            select course_id, sec_id, semester, year
            from takes t
            join student s on t.id = s.id
            where s.name = s_name
        ),
        instructors_for_courses as (
            select i.name
            from instructor i
            join teaches t on i.id = t.id
            join courses_attended ca
                on ca.course_id = t.course_id
                and ca.sec_id = t.sec_id
                and ca.semester = t.semester
                and ca.year = t.year
        ),
        advisors_for_student as (
            select i.name
            from student s
            join advisor a on s.id = a.s_id
            left join instructor i on a.i_id = i.id
            where s.name = s_name
        )
        select string_agg(distinct name, ', ')
        into ia_list
        from (
            select * from instructors_for_courses
            union
            select * from advisors_for_student
        ) all_instructors;

        return ia_list;
    end;
    $$;
-- test queries:
select taught_by('Shankar');
select name, taught_by(name) from student;

-- Q10
-- q10.1 | add extra column "teachers" to student table
alter table student add column teachers text;
-- q10.2 | update "teachers" column in students to list of their teachers
update student s set teachers = taught_by(s.name);
-- q10.3 | create 2 insert triggers that keep the "teachers" column up to date after insert on takes and advisor tables
-- takes trigger function:
create or replace function update_teachers_on_takes_update()
returns trigger
language plpgsql as $$
begin
    update student s
    set teachers = taught_by(s.name)
    where s.id = new.id;
    return new;
end;
$$;
-- takes trigger:
create trigger takes_update
after insert or update on takes
for each row
execute function update_teachers_on_takes_update();

-- advisor trigger function:
create or replace function update_teachers_on_advisor_update()
returns trigger
language plpgsql as $$
begin
    update student s
    set teachers = taught_by(s.name)
    where s.id = new.s_id;
    return new;
end;
$$;
-- advisor trigger:
create trigger advisor_update
after insert or update on advisor
for each row
execute function update_teachers_on_advisor_update();

-- q10.4 | show that it works
-- test queries:
select id, name,teachers,followed_courses_by(name) from student;
insert into takes values ('12345', 'BIO-101', '1', 'Summer', '2017', 'A');
insert into takes values ('12345', 'HIS-351', '1', 'Spring', '2018', 'B');
insert into advisor values ('54321', '32343');
insert into advisor values ('55739', '76543');
select id, name,teachers,followed_courses_by(name) from student;
