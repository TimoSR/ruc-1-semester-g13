-- SELECT t.course_id, c.title, c.credits AS sum
-- FROM takes t
-- JOIN course c ON t.course_id = c.course_id
-- WHERE t.id = '30397';

-- corrected version with SUM:
SELECT course_id, title, SUM(c.credits) AS sum
FROM takes t
JOIN course c ON t.course_id = c.course_id
WHERE t.id = '30397'
GROUP BY t.course_id, c.title;
