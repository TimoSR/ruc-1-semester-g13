WITH passed AS (
  SELECT
    t.id AS student_id,
    SUM(c.credits) AS passed_credits
  FROM takes t
  JOIN course c ON c.course_id = t.course_id
  WHERE t.grade IS NOT NULL AND t.grade <> 'F'
  GROUP BY t.id
)
SELECT
  s.id,
  s.tot_cred,
  COALESCE(p.passed_credits, 0) AS sum
FROM student s
LEFT JOIN passed p ON p.student_id = s.id
WHERE s.tot_cred <> COALESCE(p.passed_credits, 0)
ORDER BY s.id;
