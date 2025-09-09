SELECT 
    course.course_id,
    course.title
FROM takes
JOIN course 
    ON takes.course_id = course.course_id
WHERE takes.ID = '30397'
ORDER BY course.course_id;