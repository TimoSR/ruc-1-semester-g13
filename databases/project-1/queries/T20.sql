WITH section_count AS (
    SELECT  id, COUNT(DISTINCT sec_id) as sec_cnt
    FROM teaches as t
    JOIN instructor as i ON t.id = i.id
    GROUP BY id
)
UPDATE instructor
SET salary = 29001 + (10000 * section_count.sec_cnt)
FROM section_count
WHERE instructor.id = section_count.id;

