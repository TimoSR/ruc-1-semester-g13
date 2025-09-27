-- Required

WITH section_counts AS (
    SELECT course_id, sec_id, semester, year, COUNT(*) AS enrollment_count
    FROM takes
    GROUP BY course_id, sec_id, semester, year
)
SELECT course_id, sec_id, semester, year, enrollment_count
FROM section_counts
WHERE enrollment_count = (
    SELECT MAX(enrollment_count)
    FROM section_counts
);

-- Optimized 

WITH section_counts AS (
    SELECT 
        course_id, 
        sec_id, 
        semester, 
        year, 
        COUNT(*) AS enrollment_count
    FROM takes
    GROUP BY course_id, sec_id, semester, year
),

max_enrollment AS (
    SELECT MAX(enrollment_count) AS max_count
    FROM section_counts
)

SELECT 
    course_id, 
    sec_id, 
    semester, 
    year, 
    enrollment_count
FROM section_counts
WHERE enrollment_count = (SELECT max_count FROM max_enrollment);