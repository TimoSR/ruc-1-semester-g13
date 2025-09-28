SELECT i.id
FROM instructor i
WHERE i.dept_name = 'Marketing'
  AND NOT EXISTS (
    SELECT 1
    FROM teaches t
    WHERE t.id = i.id
  );
