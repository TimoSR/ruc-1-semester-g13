SELECT MAX(num), MIN(num)
FROM (
  SELECT course_id, sec_id, semester, year, COUNT(id) AS num
  FROM takes
  GROUP BY course_id, sec_id, semester, year
) AS enrollment;
