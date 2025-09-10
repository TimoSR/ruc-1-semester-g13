WITH enrollment AS (
  SELECT course_id, sec_id, semester, year, COUNT(id) AS num
  FROM takes
  GROUP BY course_id, sec_id, semester, year
)
SELECT MAX(num), MIN(num)
FROM enrollment;
