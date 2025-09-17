CREATE OR REPLACE FUNCTION taught_by(student_name_param VARCHAR(20))
RETURNS TEXT AS $$
DECLARE
    result TEXT := '';
    next_instructor VARCHAR(20);
    instructor_cursor CURSOR FOR
        SELECT DISTINCT i.name
        FROM instructor i
        WHERE i.id IN (
           
            SELECT DISTINCT t.id
            FROM teaches t
            JOIN takes ta ON t.course_id = ta.course_id 
                AND t.sec_id = ta.sec_id 
                AND t.semester = ta.semester 
                AND t.year = ta.year
            JOIN student s ON ta.id = s.id
            WHERE s.name = student_name_param
            
            UNION
            
            SELECT DISTINCT a.i_id
            FROM advisor a
            JOIN student s ON a.s_id = s.id
            WHERE s.name = student_name_param
        )
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

-- Test queries:
SELECT taught_by('Shankar');
SELECT name, taught_by(name) FROM student;
