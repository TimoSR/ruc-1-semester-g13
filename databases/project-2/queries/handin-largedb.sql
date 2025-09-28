-- GROUP: cit12, MEMBERS: Chiara Visca, Christopher Mads Hammerum Bouet, Mana Karki, Timothy Stoltzner Rasmussen

-- 1

SELECT * from takes;

CREATE OR REPLACE FUNCTION course_count(student_id VARCHAR) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  course_total INTEGER;
BEGIN
  SELECT COUNT(course_id)
  INTO course_total
  FROM takes
  WHERE id = student_id;
  
  RETURN course_total;
END;
$$;

SELECT course_count('65901');
SELECT student.id, course_count(id) from student;

-- 2

CREATE OR REPLACE FUNCTION course_count_2(student_id VARCHAR, department_name VARCHAR)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  course_total INTEGER;
BEGIN
  SELECT COUNT(*) INTO course_total
  FROM takes
  JOIN course ON takes.course_id = course.course_id
  WHERE takes.id = student_id AND course.dept_name ILIKE department_name;
  RETURN course_total;
END;
$$;

SELECT course_count_2('65901','comp. sci.');
SELECT id,name,course_count_2(id,'Comp. Sci.') from student;

-- 3

-- in PostgreSQL we cant define optional parameters But you can achieve the same effect by function overloading

CREATE OR REPLACE FUNCTION course_count(student_id VARCHAR)
RETURNS INTEGER
LANGUAGE sql
AS $$
  SELECT COUNT(course_id)
  FROM takes
  WHERE id = student_id;
$$;

CREATE OR REPLACE FUNCTION course_count(student_id VARCHAR, department_name VARCHAR)
RETURNS INTEGER
LANGUAGE sql
AS $$
  SELECT COUNT(*)
  FROM takes
  JOIN course ON takes.course_id = course.course_id
  WHERE takes.id = student_id AND course.dept_name ILIKE department_name;
$$;

-- One-parameter usage
SELECT course_count('65901');

-- Two-parameter usage
SELECT course_count('65901','comp. sci.');

-- 4

CREATE OR REPLACE FUNCTION department_activities(department_name VARCHAR)
RETURNS TABLE(
    instructor_name VARCHAR,
    course_title VARCHAR,
    semester VARCHAR,
    year INT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT instructor.name AS instructor_name,
         course.title AS course_title,
         section.semester,
         section.year::INT
  FROM instructor
  JOIN teaches ON instructor.id = teaches.id
  JOIN section ON teaches.course_id = section.course_id
                AND teaches.sec_id   = section.sec_id
                AND teaches.semester = section.semester
                AND teaches.year     = section.year
  JOIN course ON section.course_id = course.course_id
  WHERE instructor.dept_name ILIKE department_name;
END;
$$;

SELECT * FROM department_activities('Comp. Sci.');

-- 5

CREATE OR REPLACE FUNCTION activities(input_name VARCHAR)
RETURNS TABLE(
    dept_name VARCHAR,
    instructor_name VARCHAR,
    course_title VARCHAR,
    semester VARCHAR,
    year INT
)
LANGUAGE sql
AS $$
WITH base AS (
    SELECT department.dept_name,
           instructor.name,
           course.title,
           section.semester,
           section.year,
           department.building
    FROM instructor
    JOIN teaches ON instructor.id = teaches.id
    JOIN section ON teaches.course_id = section.course_id
                AND teaches.sec_id   = section.sec_id
                AND teaches.semester = section.semester
                AND teaches.year     = section.year
    JOIN course ON section.course_id = course.course_id
    JOIN department ON instructor.dept_name = department.dept_name
)
SELECT dept_name,
       name AS instructor_name,
       title AS course_title,
       semester,
       year::INT
FROM base
WHERE dept_name ILIKE input_name
   OR building ILIKE input_name;
$$;

-- Input is a department
SELECT * FROM activities('Comp. Sci.');

-- Input is a building
SELECT * FROM activities('Mercer');

-- 6

CREATE OR REPLACE FUNCTION followed_courses_by(student_name VARCHAR)
RETURNS TEXT
LANGUAGE sql
AS $$
WITH taught AS (
    SELECT DISTINCT instructor.name AS instructor_name
    FROM student
    JOIN takes ON student.id = takes.id
    JOIN teaches ON takes.course_id = teaches.course_id
                AND takes.sec_id   = teaches.sec_id
                AND takes.semester = teaches.semester
                AND takes.year     = teaches.year
    JOIN instructor ON teaches.id = instructor.id
    WHERE student.name = student_name
)
SELECT string_agg(instructor_name, ', ' ORDER BY instructor_name)
FROM taught;
$$;

-- Example 1: Specific student
SELECT followed_courses_by('Rumat');

-- Example 2: Another student
SELECT followed_courses_by('Samel');

-- Example 3: For all students
SELECT name, followed_courses_by(name)
FROM student;

-- 7

CREATE OR REPLACE FUNCTION followed_courses_by(student_name VARCHAR)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    result TEXT := '';
BEGIN
    FOR rec IN
        WITH taught_instructors AS (
            SELECT DISTINCT instructor.name AS instructor_name
            FROM student
            JOIN takes ON student.id = takes.id
            JOIN teaches ON takes.course_id = teaches.course_id
                        AND takes.sec_id   = teaches.sec_id
                        AND takes.semester = teaches.semester
                        AND takes.year     = teaches.year
            JOIN instructor ON teaches.id = instructor.id
            WHERE student.name = student_name
        )
        SELECT instructor_name
        FROM taught_instructors
    LOOP
        IF result = '' THEN
            result := rec.instructor_name;
        ELSE
            result := result || ', ' || rec.instructor_name;
        END IF;
    END LOOP;

    RETURN result;
END;
$$;

-- One student
SELECT followed_courses_by('Rumat');

-- All students
SELECT name, followed_courses_by(name)
FROM student;

-- 8

CREATE OR REPLACE FUNCTION followed_courses_by(student_name VARCHAR)
RETURNS TEXT
LANGUAGE sql
AS $$
WITH taught_instructors AS (
    SELECT DISTINCT instructor.name AS instructor_name
    FROM student
    JOIN takes ON student.id = takes.id
    JOIN teaches ON takes.course_id = teaches.course_id
                AND takes.sec_id   = teaches.sec_id
                AND takes.semester = teaches.semester
                AND takes.year     = teaches.year
    JOIN instructor ON teaches.id = instructor.id
    WHERE student.name = student_name
)
SELECT string_agg(instructor_name, ', ' ORDER BY instructor_name)
FROM taught_instructors;
$$;

-- Single student
SELECT followed_courses_by('Rumat');

-- All students
SELECT name, followed_courses_by(name)
FROM student;

-- 9

CREATE OR REPLACE FUNCTION taught_by(student_name VARCHAR)
RETURNS TEXT
LANGUAGE sql
AS $$
WITH instructors_from_courses AS (
    SELECT DISTINCT instructor.name AS instructor_name
    FROM student
    JOIN takes ON student.id = takes.id
    JOIN teaches ON takes.course_id = teaches.course_id
                AND takes.sec_id   = teaches.sec_id
                AND takes.semester = teaches.semester
                AND takes.year     = teaches.year
    JOIN instructor ON teaches.id = instructor.id
    WHERE student.name = student_name
),
instructors_from_advisors AS (
    SELECT DISTINCT instructor.name AS instructor_name
    FROM student
    JOIN advisor ON student.id = advisor.s_id
    JOIN instructor ON advisor.i_id = instructor.id
    WHERE student.name = student_name
),
all_instructors AS (
    SELECT * FROM instructors_from_courses
    UNION
    SELECT * FROM instructors_from_advisors
)
SELECT string_agg(instructor_name, ', ' ORDER BY instructor_name)
FROM all_instructors;
$$;

-- For one student
SELECT taught_by('Rumat');

-- For all students
SELECT name, taught_by(name)
FROM student;

-- 10

-- q10.1 | add extra column "teachers" to student table
alter table student 
add column if not exists teachers text;

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
drop trigger if exists takes_update on takes;
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
drop trigger if exists advisor_update on advisor;
create trigger advisor_update
after insert or update on advisor
for each row
execute function update_teachers_on_advisor_update();

insert into student (id, name, dept_name, tot_cred)
values ('54321', 'Temp Student A', 'Comp. Sci.', 0)
on conflict (id) do nothing;

insert into student (id, name, dept_name, tot_cred)
values ('55739', 'Temp Student B', 'History', 0)
on conflict (id) do nothing;

-- ensure instructor exists
insert into instructor (id, name, dept_name, salary)
values ('32343', 'Prof. Smith', 'Comp. Sci.', 80000)
on conflict (id) do nothing;

insert into instructor (id, name, dept_name, salary)
values ('76543', 'Prof. Brown', 'History', 70000)
on conflict (id) do nothing;

-- now your advisor inserts will succeed
INSERT INTO advisor (s_id, i_id)
VALUES ('54321', '32343')
ON CONFLICT DO NOTHING;

INSERT INTO advisor (s_id, i_id)
VALUES ('55739', '76543')
ON CONFLICT DO NOTHING;

SELECT id, name,teachers,followed_courses_by(name) from student;