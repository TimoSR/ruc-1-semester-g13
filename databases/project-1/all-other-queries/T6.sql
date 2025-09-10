SELECT DISTINCT stud.name
FROM student AS stud
JOIN takes AS tak ON stud.ID = tak.ID
JOIN course AS cou ON tak.course_id = cou.course_id
WHERE tak.grade = 'A+'
  AND cou.dept_name = 'Languages';
  