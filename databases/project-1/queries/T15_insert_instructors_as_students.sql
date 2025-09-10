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