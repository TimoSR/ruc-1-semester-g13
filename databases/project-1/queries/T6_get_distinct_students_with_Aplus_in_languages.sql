SELECT DISTINCT student.name
FROM student
JOIN takes 
    ON student.ID = takes.ID
JOIN course
    ON takes.course_id = course.course_id
WHERE course.dept_name = 'Languages'
  AND takes.grade = 'A+'
ORDER BY student.name;