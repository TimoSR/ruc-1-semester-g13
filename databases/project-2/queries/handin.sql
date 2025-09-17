-- 1

select * from takes;

CREATE OR REPLACE FUNCTION course_count(student_id VARCHAR) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  course_total INTEGER;
BEGIN
  SELECT COUNT(course_id) INTO course_total
  FROM takes
  WHERE id = student_id;
  RETURN course_total;
END;
$$;

SELECT FROM course_count('12345');
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

select course_count_2('12345','Comp. Sci.');
select id,name,course_count_2(id,'Comp. Sci.') from student;

-- 3

-- in PostgreSQL we cant define optional parameters But you can achieve the same effect by function overloading

CREATE OR REPLACE FUNCTION course_count(student_id VARCHAR)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
  SELECT COUNT(course_id)
  FROM takes
  WHERE id = student_id;
$$;

CREATE OR REPLACE FUNCTION course_count(student_id VARCHAR, department_name VARCHAR)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
  SELECT COUNT(*)
  FROM takes
  JOIN course ON takes.course_id = course.course_id
  WHERE takes.id = student_id AND course.dept_name ILIKE department_name;
$$;

-- One-parameter usage
SELECT course_count('12345');

-- Two-parameter usage
SELECT course_count('12345', 'Comp. Sci.');

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
SELECT * FROM activities('Watson');

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
SELECT followed_courses_by('Levy');

-- Example 2: Another student
SELECT followed_courses_by('Shankar');

-- Example 3: For all students
SELECT name, followed_courses_by(name) FROM student;

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
SELECT followed_courses_by('Shankar');

-- All students
SELECT name, followed_courses_by(name) FROM student;

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
SELECT followed_courses_by('Shankar');

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
SELECT taught_by('Shankar');

-- For all students
SELECT name, taught_by(name)
FROM student;

-- 10

------------------------------------------------------------
-- Step 1. Add teachers column if not exists
------------------------------------------------------------
ALTER TABLE student
ADD COLUMN IF NOT EXISTS teachers TEXT;

------------------------------------------------------------
-- Step 2. Initialize column for all existing students
------------------------------------------------------------
UPDATE student
SET teachers = taught_by(name);

------------------------------------------------------------
-- Step 3. Takes trigger function
------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_teachers_on_takes_update()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE student s
    SET teachers = taught_by(s.name)
    WHERE s.id = NEW.id;
    RETURN NEW;
END;
$$;

-- Drop old trigger if it exists, then recreate
DROP TRIGGER IF EXISTS takes_update ON takes;
CREATE TRIGGER takes_update
AFTER INSERT OR UPDATE ON takes
FOR EACH ROW
EXECUTE FUNCTION update_teachers_on_takes_update();

------------------------------------------------------------
-- Step 4. Advisor trigger function
------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_teachers_on_advisor_update()
RETURNS TRIGGER
LANGUAGE plpgsql 
AS $$
BEGIN
    UPDATE student s
    SET teachers = taught_by(s.name)
    WHERE s.id = NEW.s_id;
    RETURN NEW;
END;
$$;

-- Drop old trigger if it exists, then recreate
DROP TRIGGER IF EXISTS advisor_update ON advisor;
CREATE TRIGGER advisor_update
AFTER INSERT OR UPDATE ON advisor
FOR EACH ROW
EXECUTE FUNCTION update_teachers_on_advisor_update();

------------------------------------------------------------
-- Step 5. Test queries
------------------------------------------------------------
-- Show before
SELECT id, name, teachers, followed_courses_by(name) FROM student;

-- Ensure section exists
INSERT INTO section (course_id, sec_id, semester, year, building, room_number, time_slot_id)
VALUES ('BIO-101', '1', 'Summer', 2017, 'Watson', '100', 'A1')
ON CONFLICT DO NOTHING;  -- avoids error if it already exists

INSERT INTO section (course_id, sec_id, semester, year, building, room_number, time_slot_id)
VALUES ('HIS-351', '1', 'Spring', 2018, 'Packard', '201', 'B2')
ON CONFLICT DO NOTHING;

-- Insert new course registrations
INSERT INTO takes VALUES ('12345', 'BIO-101', '1', 'Summer', '2017', 'A');
INSERT INTO takes VALUES ('12345', 'HIS-351', '1', 'Spring', '2018', 'B');

-- Insert new advisors
INSERT INTO advisor VALUES ('54321', '32343');
INSERT INTO advisor VALUES ('55739', '76543');

-- Show after
SELECT id, name, teachers, followed_courses_by(name) FROM student;
