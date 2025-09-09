SELECT 
    MAX(enrollment_count) AS max,
    MIN(0) AS min
FROM (
    SELECT 
        section.course_id,
        section.sec_id,
        section.semester,
        section.year,
        COUNT(takes.ID) AS enrollment_count
    FROM section section
    LEFT JOIN takes
        ON section.course_id = takes.course_id
       AND section.sec_id   = takes.sec_id
       AND section.semester = takes.semester
       AND section.year     = takes.year
    GROUP BY 
        section.course_id, section.sec_id, section.semester, section.year
) AS enrollment_per_section;