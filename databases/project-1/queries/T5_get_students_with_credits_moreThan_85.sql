SELECT takes.id, SUM(course.credits) AS credit_sum
FROM takes 
JOIN course ON course.course_id= takes.course_id
GROUP BY takes.id
HAVING SUM(course.credits) > 85;