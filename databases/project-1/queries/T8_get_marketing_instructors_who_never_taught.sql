-- phase 1

SELECT * from instructor;

-- phase x

-- ....

-- phase 2

SELECT instructor.ID, "name"
FROM instructor 
WHERE instructor.dept_name = 'Marketing'
  AND NOT EXISTS (
    SELECT *
    FROM teaches 
    WHERE teaches."id"= instructor.ID
  );

  -- phase 3 (optimizing readabilit)(DONE)

WITH InstructorsWhoHaveTaught AS (
SELECT DISTINCT teaches.id
FROM teaches
),
MarketingInstructorsWhoNeverTaught AS (
  SELECT instructor.ID, instructor.name
  FROM instructor
  WHERE instructor.dept_name = 'Marketing'
    AND instructor.ID NOT IN (SELECT id FROM InstructorsWhoHaveTaught)
)

SELECT *
FROM MarketingInstructorsWhoNeverTaught;