SELECT instructor.ID, "name"
FROM instructor 
WHERE instructor.dept_name = 'Marketing'
  AND NOT EXISTS (
    SELECT *
    FROM teaches 
    WHERE teaches."id"= instructor.ID
  );