-- Required

SELECT DISTINCT inst.id
FROM instructor as inst
WHERE NOT EXISTS ( (SELECT course_id
                    FROM course
                    WHERE course_id IN ('581', '545', '591'))
                  EXCEPT
                    (SELECT tea.course_id
                     FROM teaches as tea
                     WHERE tea.id = inst.id));

-- Optimized

WITH target_courses AS (
    SELECT course_id
    FROM course
    WHERE course_id IN ('581', '545', '591')
)

SELECT DISTINCT inst.id
FROM instructor AS inst
WHERE NOT EXISTS (
    SELECT course_id
    FROM target_courses
    EXCEPT
    SELECT tea.course_id
    FROM teaches AS tea
    WHERE tea.id = inst.id
);