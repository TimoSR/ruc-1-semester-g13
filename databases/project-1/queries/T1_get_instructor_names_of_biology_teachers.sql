-- Phase 1
-- * all wildcard

select * from course;

-- Phase 2 (DONE)

SELECT instructor.name 
FROM instructor
WHERE instructor.dept_name = 'Biology';