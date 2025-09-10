SELECT course_id, sec_id, semester, year, enrollment_count
FROM (
    SELECT course_id, sec_id, semester, year, COUNT(ID) AS enrollment_count
    FROM takes
    GROUP BY course_id, sec_id, semester, year
) AS section_counts
WHERE enrollment_count = (
    SELECT MAX(enrollment_count)
    FROM (
        SELECT COUNT(ID) AS enrollment_count
        FROM takes
        GROUP BY course_id, sec_id, semester, year
    ) AS counts
);
