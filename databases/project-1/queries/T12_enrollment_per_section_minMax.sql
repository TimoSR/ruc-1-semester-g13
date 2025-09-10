WITH AllSections AS (
    SELECT 
        course_id,
        sec_id,
        semester,
        year
    FROM section
),

Enrollments AS (
    SELECT 
        takes.course_id,
        takes.sec_id,
        takes.semester,
        takes.year,
        COUNT(takes.ID) AS enrollment_count
    FROM takes
    GROUP BY takes.course_id, takes.sec_id, takes.semester, takes.year
),

EnrollmentPerSection AS (
    SELECT 
        AllSections.course_id,
        AllSections.sec_id,
        AllSections.semester,
        AllSections.year,
        COALESCE(Enrollments.enrollment_count, 0) AS enrollment_count
    FROM AllSections
    LEFT JOIN Enrollments
      ON AllSections.course_id = Enrollments.course_id
     AND AllSections.sec_id   = Enrollments.sec_id
     AND AllSections.semester = Enrollments.semester
     AND AllSections.year     = Enrollments.year
)

SELECT 
    MAX(enrollment_count) AS max_enrollment,
    MIN(enrollment_count) AS min_enrollment
FROM EnrollmentPerSection;