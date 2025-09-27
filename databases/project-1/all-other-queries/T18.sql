UPDATE student
SET tot_cred = (
    SELECT s.total
    FROM (
        SELECT t.id, SUM(c.credits) AS total
        FROM takes AS t
        JOIN course AS c ON t.course_id = c.course_id
        WHERE t.grade <> 'F' AND t.grade IS NOT NULL
        GROUP BY t.id
    ) AS s
    WHERE s.id = student.id
);
