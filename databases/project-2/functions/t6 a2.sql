CREATE OR REPLACE FUNCTION followed_courses_by(student_name_param VARCHAR(20))
RETURNS TEXT AS $$
DECLARE
    result TEXT := '';
    next_instructor VARCHAR(20);
    instructor_cursor CURSOR FOR
        SELECT DISTINCT i.name
        FROM instructor i
        JOIN teaches t ON i.id = t.id
        JOIN takes ta ON t.course_id = ta.course_id 
            AND t.sec_id = ta.sec_id 
            AND t.semester = ta.semester 
            AND t.year = ta.year
        JOIN student s ON ta.id = s.id
        WHERE s.name = student_name_param
        ORDER BY i.name;
BEGIN
    FOR next_instructor IN instructor_cursor LOOP
        IF result = '' THEN
            result := next_instructor;
        ELSE
            result := result || ', ' || next_instructor;
        END IF;
    END LOOP;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;


-- TEST QUERIES

SELECT followed_courses_by('Shankar');

SELECT name, followed_courses_by(name) FROM student;
