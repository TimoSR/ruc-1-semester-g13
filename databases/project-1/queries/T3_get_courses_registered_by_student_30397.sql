SELECT course.course_id, course.title
FROM course
JOIN takes ON course.course_id = takes.course_id
WHERE takes.id = '30397';