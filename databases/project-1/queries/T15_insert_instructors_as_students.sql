INSERT INTO student (ID, name, dept_name, tot_cred)
SELECT 
    instructor.ID, 
    instructor.name, 
    instructor.dept_name, 
    0 AS tot_cred
FROM instructor
WHERE NOT EXISTS (
    SELECT 1 
    FROM student 
    WHERE student.ID = instructor.ID
);