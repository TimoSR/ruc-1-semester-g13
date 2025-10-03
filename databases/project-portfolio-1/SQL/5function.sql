-- 5
-- Not working
CREATE OR REPLACE FUNCTION find_person_by_name(search_term varchar)
RETURNS TABLE (
person_id varchar(50),
name varchar(50)
) AS $$
BEGIN
RETURN QUERY
SELECT p.person_id, p.name
FROM person p
WHERE p.name ILIKE '%' || search_term || '%'   --case-insensitive
ORDER BY p.name
LIMIT 1;
END;
$$ LANGUAGE plpgsql;


-- Fixed
DROP FUNCTION IF EXISTS find_person_by_name(varchar);

-- Create correct version (matches your schema)
CREATE OR REPLACE FUNCTION find_person_by_name(search_term TEXT)
RETURNS TABLE (
  person_id VARCHAR(50),
  name      TEXT
)
LANGUAGE sql
AS $$
  SELECT p.id::varchar(50) AS person_id,
         p.primary_name     AS name
  FROM person p
  WHERE p.primary_name ILIKE '%' || search_term || '%'
  ORDER BY p.primary_name
  LIMIT 1;   -- keep her original behaviour
$$;