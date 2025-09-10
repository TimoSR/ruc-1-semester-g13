-- Phase 1 (Required)

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

-- Phase 2 (Optimized)

WITH section_enrollments AS (
    SELECT 
        course_id, 
        sec_id, 
        semester, 
        year, 
        COUNT(ID) AS enrollment_count
    FROM takes
    GROUP BY course_id, sec_id, semester, year
),

max_enrollment AS (
    SELECT MAX(enrollment_count) AS max_count
    FROM section_enrollments
)

SELECT 
    course_id, 
    sec_id, 
    semester, 
    year, 
    enrollment_count
FROM section_enrollments
WHERE enrollment_count = (SELECT max_count FROM max_enrollment);