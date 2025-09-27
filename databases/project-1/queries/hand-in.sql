-- 1

SELECT instructor.name 
FROM instructor
WHERE instructor.dept_name = 'Biology';

-- 2

SELECT title
FROM course
WHERE dept_name = 'Comp. Sci.'
AND credits = 3;

-- 3

SELECT DISTINCT
    course.course_id,
    course.title
FROM takes
JOIN course 
    ON takes.course_id = course.course_id
WHERE takes.ID = '30397'
ORDER BY course.course_id;

-- 4

SELECT t.course_id, c.title, SUM(c.credits) AS sum
FROM takes t
JOIN course c ON t.course_id = c.course_id
WHERE t.id = '30397'
GROUP BY t.course_id, c.title
ORDER BY t.course_id;

-- 5

SELECT takes.id, SUM(course.credits) AS credit_sum
FROM takes 
JOIN course ON course.course_id= takes.course_id
GROUP BY takes.id
HAVING SUM(course.credits) > 85;

-- 6

SELECT DISTINCT student.name
FROM student
JOIN takes 
    ON student.ID = takes.ID
JOIN course
    ON takes.course_id = course.course_id
WHERE course.dept_name = 'Languages'
  AND takes.grade = 'A+'
ORDER BY student.name;

-- 7

SELECT i.id
FROM instructor i
WHERE i.dept_name = 'Marketing'
  AND NOT EXISTS (
    SELECT 1
    FROM teaches t
    WHERE t.id = i.id
  );


-- 8

SELECT instructor.ID, "name"
FROM instructor 
WHERE instructor.dept_name = 'Marketing'
  AND NOT EXISTS (
    SELECT *
    FROM teaches 
    WHERE teaches."id"= instructor.ID
  );

-- 9

WITH StudentCountPerSection AS (
    SELECT 
        course_id,
        sec_id,
        semester,
        year,
        COUNT(ID) AS student_count
    FROM takes
    WHERE year = 2009
    GROUP BY course_id, sec_id, semester, year
)

SELECT *
FROM StudentCountPerSection
ORDER BY course_id, sec_id;

-- 10A

SELECT MAX(num), MIN(num)
FROM (
  SELECT course_id, sec_id, semester, year, COUNT(id) AS num
  FROM takes
  GROUP BY course_id, sec_id, semester, year
) AS enrollment;


-- 10B

WITH enrollment AS (
  SELECT course_id, sec_id, semester, year, COUNT(id) AS num
  FROM takes
  GROUP BY course_id, sec_id, semester, year
)
SELECT MAX(num), MIN(num)
FROM enrollment;

-- 11A

SELECT course_id, sec_id, semester, year, enrollment_count
FROM (
    SELECT course_id, sec_id, semester, year, COUNT(ID) AS enrollment_count
    FROM takes
    GROUP BY course_id, sec_id, semester, year
) AS section_counts
WHERE enrollment_count = (
    SELECT MAX(enrollment_count)
    FROM (
        SELECT COUNT(ID) AS enrollment_count
        FROM takes
        GROUP BY course_id, sec_id, semester, year
    ) AS counts
);

-- 11B

WITH section_counts AS (
    SELECT course_id, sec_id, semester, year, COUNT(*) AS enrollment_count
    FROM takes
    GROUP BY course_id, sec_id, semester, year
)
SELECT course_id, sec_id, semester, year, enrollment_count
FROM section_counts
WHERE enrollment_count = (
    SELECT MAX(enrollment_count)
    FROM section_counts
);

-- 12

WITH EnrollmentPerSection AS (
    SELECT 
        section.course_id,
        section.sec_id,
        section.semester,
        section.year,
        COALESCE(COUNT(takes.ID), 0) AS enrollment_count
    FROM section
    LEFT JOIN takes
      ON section.course_id = takes.course_id
     AND section.sec_id   = takes.sec_id
     AND section.semester = takes.semester
     AND section.year     = takes.year
    GROUP BY section.course_id, section.sec_id, section.semester, section.year
)

SELECT 
    MAX(enrollment_count) AS max_enrollment,
    MIN(enrollment_count) AS min_enrollment
FROM EnrollmentPerSection;

-- 13

SELECT id, course_id, sec_id, semester, year
FROM teaches
WHERE id = '19368';

-- 14

SELECT DISTINCT inst.id
FROM instructor as inst
WHERE NOT EXISTS ( (SELECT course_id
                    FROM course
                    WHERE course_id IN ('581', '545', '591'))
                  EXCEPT
                    (SELECT tea.course_id
                     FROM teaches as tea
                     WHERE tea.id = inst.id));

-- 15

WITH NewInstructors AS (
  SELECT instructor.ID, instructor.name, instructor.dept_name
  FROM instructor
  WHERE NOT EXISTS (
    SELECT 1
    FROM student
    WHERE student.ID = instructor.ID
  )
)

INSERT INTO student (ID, name, dept_name, tot_cred)
SELECT ID, name, dept_name, 0
FROM NewInstructors;

-- 16

DELETE FROM student
WHERE id IN (SELECT id FROM instructor)
  AND tot_cred = 0;

-- 17

WITH credit_sum AS (
    SELECT id, SUM(credits) as c_sum
    FROM takes NATURAL JOIN course
    GROUP BY id
)

SELECT id, tot_cred, c_sum
FROM student natural join credit_sum
WHERE tot_cred = c_sum;

-- 18

WITH EarnedCredits AS (
  SELECT takes.ID, SUM(course.credits) AS total_credits
  FROM takes
  JOIN course ON takes.course_id = course.course_id
  WHERE takes.grade IS NOT NULL
    AND takes.grade NOT IN ('F')
  GROUP BY takes.ID
)

UPDATE student
SET tot_cred = COALESCE((
  SELECT total_credits
  FROM EarnedCredits
  WHERE EarnedCredits.ID = student.ID
), 0);

-- 19

WITH passed AS (
  SELECT
    t.id AS student_id,
    SUM(c.credits) AS passed_credits
  FROM takes t
  JOIN course c ON c.course_id = t.course_id
  WHERE t.grade IS NOT NULL AND t.grade <> 'F'
  GROUP BY t.id
)
SELECT
  s.id,
  s.tot_cred,
  COALESCE(p.passed_credits, 0) AS sum
FROM student s
LEFT JOIN passed p ON p.student_id = s.id
WHERE s.tot_cred <> COALESCE(p.passed_credits, 0)
ORDER BY s.id;

-- 20

WITH section_count AS (
    SELECT inst.id, COUNT(tea.sec_id) AS sec_cnt
    FROM instructor AS inst
    LEFT JOIN teaches AS tea ON inst.id = tea.id
    GROUP BY inst.id
)
UPDATE instructor AS i
SET salary = 29001 + (10000 * s.sec_cnt)
FROM section_count AS s
WHERE i.id = s.id;

-- 21

SELECT instructor.id, instructor.name, instructor.salary
FROM instructor
ORDER BY instructor.name
LIMIT 10 ;