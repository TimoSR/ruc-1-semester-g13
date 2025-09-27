SELECT course_id, sec_id, year, semester, COUNT(ID) AS num
FROM takes
WHERE year = 2009
GROUP BY course_id, sec_id, semester, year;
