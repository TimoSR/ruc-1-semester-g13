-- Phase 1

select * from course;

-- phase 2
-- Look at the structure of the data given

select * from course where credits = 3;

-- phase 3 (DONE)

SELECT course.title
FROM course
WHERE
    course.credits = 3
    AND course.dept_name = 'Comp. Sci.';