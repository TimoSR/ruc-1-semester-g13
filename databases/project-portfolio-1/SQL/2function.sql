-- 2

CREATE OR REPLACE FUNCTION string_search(p_profile_id INT, p_query TEXT)
RETURNS TABLE (tconst VARCHAR(20), primarytitle VARCHAR(500))
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO search_history(profile_id, search_query)
  VALUES (p_profile_id, p_query);

  RETURN QUERY
  SELECT t.id, t.primary_title
  FROM title t
  WHERE t.primary_title ILIKE '%' || p_query || '%'
     OR t.plot          ILIKE '%' || p_query || '%';
END;
$$;
