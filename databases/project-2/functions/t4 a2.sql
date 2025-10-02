CREATE OR REPLACE FUNCTION department_activities(dept_name_param VARCHAR(20))
RETURNS TABLE (
    instructor_name VARCHAR(20),
    course_title VARCHAR(50),
    semester VARCHAR(6),
    year NUMERIC(4,0)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.name AS instructor_name,
        c.title AS course_title,
        s.semester,
        s.year
    FROM instructor i
    JOIN teaches t ON i.id = t.id
    JOIN course c ON t.course_id = c.course_id
    JOIN section s ON t.course_id = s.course_id 
        AND t.sec_id = s.sec_id 
        AND t.semester = s.semester 
        AND t.year = s.year
    WHERE i.dept_name = dept_name_param
    ORDER BY s.year DESC, s.semester, i.name, c.title;
END;
$$ LANGUAGE plpgsql;


--
SELECT department_activities('Comp. Sci.');
