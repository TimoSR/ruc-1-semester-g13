SELECT DISTINCT student.name
FROM takes
JOIN course ON takes.course_id = course.course_id
JOIN student ON takes.id = student.id
WHERE course.dept_name = 'Languages'
  AND takes.grade = 'A+';