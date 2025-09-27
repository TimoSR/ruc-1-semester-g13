WITH EnrollmentPerSection AS (
    SELECT 
        section.course_id,
        section.sec_id,
        section.semester,
        section.year,
        COALESCE(COUNT(takes.ID), 0) AS enrollment_count
    FROM section
    LEFT JOIN takes
      ON section.course_id = takes.course_id
     AND section.sec_id   = takes.sec_id
     AND section.semester = takes.semester
     AND section.year     = takes.year
    GROUP BY section.course_id, section.sec_id, section.semester, section.year
)

SELECT 
    MAX(enrollment_count) AS max_enrollment,
    MIN(enrollment_count) AS min_enrollment
FROM EnrollmentPerSection;