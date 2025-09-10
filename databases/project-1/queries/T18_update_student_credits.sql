
-- I would change the naming of tot_cred to total

WITH EarnedCredits AS (
  SELECT takes.ID, SUM(course.credits) AS total_credits
  FROM takes
  JOIN course ON takes.course_id = course.course_id
  WHERE takes.grade IS NOT NULL
    AND takes.grade NOT IN ('F')
  GROUP BY takes.ID
)

UPDATE student
SET tot_cred = COALESCE((
  SELECT total_credits
  FROM EarnedCredits
  WHERE EarnedCredits.ID = student.ID
), 0);