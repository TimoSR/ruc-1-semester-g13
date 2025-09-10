SELECT course_id, title, SUM(credits) as cred_sum
FROM takes NATURAL JOIN course
WHERE id = '30397'
GROUP BY course_id, title;
