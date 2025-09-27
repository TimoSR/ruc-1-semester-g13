SELECT inst.ID
FROM instructor as inst
WHERE inst.dept_name = 'Marketing'
    AND NOT EXISTS (
        SELECT 1
        FROM teaches as tea
        WHERE tea.ID = inst.ID
);
