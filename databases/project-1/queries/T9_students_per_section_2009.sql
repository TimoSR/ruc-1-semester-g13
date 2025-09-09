SELECT 
    takes.course_id,
    takes.sec_id,
    takes.semester,
    takes.year,
    COUNT(takes.ID) AS student_count
FROM takes
WHERE takes.year = 2009
GROUP BY 
    takes.course_id, 
    takes.sec_id, 
    takes.semester, 
    takes.year
ORDER BY 
    takes.course_id, 
    takes.sec_id;