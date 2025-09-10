-- phase 1

-- i get all the info of the courses taken by the studetn '79352'
-- there is a bad practise here it is not defined it is a student id that is takes.id
-- should be takes.student_id
select * from takes where takes.id = '30397';

--

SELECT DISTINCT
    course.course_id,
    course.title
FROM takes
JOIN course 
    ON takes.course_id = course.course_id
WHERE takes.ID = '30397'
ORDER BY course.course_id;