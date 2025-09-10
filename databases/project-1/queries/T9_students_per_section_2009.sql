WITH StudentCountPerSection AS (
    SELECT 
        course_id,
        sec_id,
        semester,
        year,
        COUNT(ID) AS student_count
    FROM takes
    WHERE year = 2009
    GROUP BY course_id, sec_id, semester, year
)

SELECT *
FROM StudentCountPerSection
ORDER BY course_id, sec_id;