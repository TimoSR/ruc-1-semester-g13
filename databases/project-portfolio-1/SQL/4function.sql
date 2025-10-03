-- 4

CREATE OR REPLACE FUNCTION structured_string_search(
  p_profile_id INT,
  p_title_q    TEXT,
  p_plot_q     TEXT,
  p_char_q     TEXT,
  p_person_q   TEXT
)
RETURNS TABLE (tconst VARCHAR(20), primarytitle VARCHAR(500))
LANGUAGE plpgsql
AS $$
DECLARE
  v_has_actor  BOOLEAN;
  v_has_person BOOLEAN;
  sql TEXT := 'SELECT DISTINCT t.id, t.primary_title FROM title t';
  where_clauses TEXT := ' WHERE 1=1';
  -- param-variables
  p1 TEXT; p2 TEXT; p3 TEXT; p4 TEXT;
  n  INT := 0;
BEGIN
  -- log i search_history 
  INSERT INTO search_history(profile_id, search_query)
  VALUES (p_profile_id,
          CONCAT_WS(' | ',
            NULLIF('title='||COALESCE(p_title_q,''), 'title='),
            NULLIF('plot='||COALESCE(p_plot_q,''), 'plot='),
            NULLIF('char='||COALESCE(p_char_q,''), 'char='),
            NULLIF('person='||COALESCE(p_person_q,''), 'person=')
          )
  );

  SELECT EXISTS (
           SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
           WHERE c.relname='actor' AND n.nspname='public'
         ) INTO v_has_actor;

  SELECT EXISTS (
           SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
           WHERE c.relname='person' AND n.nspname='public'
         ) INTO v_has_person;

  -- Join with actor/person if available (for character/person search).
  IF v_has_actor THEN
    sql := sql || ' LEFT JOIN actor a ON a.title_id = t.id';
    IF v_has_person THEN
      sql := sql || ' LEFT JOIN person p ON p.id = a.person_id';
    END IF;
  END IF;

  -- title filter
  IF p_title_q IS NOT NULL AND p_title_q <> '' THEN
    p1 := '%' || p_title_q || '%'; n := n + 1;
    where_clauses := where_clauses || format(' AND t.primary_title ILIKE $%s', n);
  END IF;

  -- plot filter
  IF p_plot_q IS NOT NULL AND p_plot_q <> '' THEN
    p2 := '%' || p_plot_q || '%'; n := n + 1;
    where_clauses := where_clauses || format(' AND t.plot ILIKE $%s', n);
  END IF;

  -- Character filter (only if actor exists)
  IF (p_char_q IS NOT NULL AND p_char_q <> '') AND v_has_actor THEN
    p3 := '%' || p_char_q || '%'; n := n + 1;
    where_clauses := where_clauses || format(' AND a.character_name ILIKE $%s', n);
  END IF;

  -- Character filter (only if actor exists)
  IF (p_person_q IS NOT NULL AND p_person_q <> '') AND v_has_actor AND v_has_person THEN
    p4 := '%' || p_person_q || '%'; n := n + 1;
    where_clauses := where_clauses || format(' AND p.primary_name ILIKE $%s', n);
  END IF;

  sql := sql || where_clauses || ' ORDER BY t.primary_title';

  -- execute dynamically using the parameters that were actually provided.
  IF n = 0 THEN
    RETURN QUERY EXECUTE sql;                                -- no filters
  ELSIF n = 1 THEN
    RETURN QUERY EXECUTE sql USING COALESCE(p1,p2,p3,p4);
  ELSIF n = 2 THEN
    RETURN QUERY EXECUTE sql USING p1, COALESCE(p2,p3,p4);
  ELSIF n = 3 THEN
    RETURN QUERY EXECUTE sql USING p1, p2, COALESCE(p3,p4);
  ELSE  -- n = 4
    RETURN QUERY EXECUTE sql USING p1, p2, p3, p4;
  END IF;
END;
$$;
