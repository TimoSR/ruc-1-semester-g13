UPDATE student
SET tot_cred = COALESCE((
    SELECT SUM(course.credits)
    FROM takes
    JOIN course ON takes.course_id = course.course_id
    WHERE takes.ID = student.ID
      AND takes.grade IS NOT NULL
      AND takes.grade NOT IN ('F')
), 0);