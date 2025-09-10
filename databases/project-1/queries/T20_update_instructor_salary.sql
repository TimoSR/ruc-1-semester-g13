WITH section_count AS (
    SELECT inst.id, COUNT(tea.sec_id) AS sec_cnt
    FROM instructor AS inst
    LEFT JOIN teaches AS tea ON inst.id = tea.id
    GROUP BY inst.id
)
UPDATE instructor AS i
SET salary = 29001 + (10000 * s.sec_cnt)
FROM section_count AS s
WHERE i.id = s.id;

-- SELECT QUERY WITH UPDATED SALARIES TO VERIFY CORRECT UPDATE:

-- WITH section_count AS (
--     SELECT inst.id, COUNT(tea.sec_id) AS sec_cnt
--     FROM instructor AS inst
--     LEFT JOIN teaches AS tea ON inst.id = tea.id
--     GROUP BY inst.id
-- )
-- SELECT i.id, i.name, s.sec_cnt, i.salary,
--        29001 + (10000 * s.sec_cnt) AS new_salary
-- FROM instructor AS i
-- JOIN section_count AS s ON i.id = s.id
-- ORDER BY i.name;