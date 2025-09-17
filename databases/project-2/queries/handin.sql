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

