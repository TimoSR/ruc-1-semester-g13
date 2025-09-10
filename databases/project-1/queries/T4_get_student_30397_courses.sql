SELECT t.course_id, c.title, c.credits AS sum
FROM takes t
JOIN course c ON t.course_id = c.course_id
WHERE t.id = '30397';
