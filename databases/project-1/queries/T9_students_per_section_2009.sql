SELECT 
    takes.course_id,
    takes.sec_id,
    takes.year,
    takes.semester,
    COUNT(*) AS num
FROM takes
WHERE takes.year = 2009
GROUP BY takes.course_id, takes.sec_id, takes.year, takes.semester;