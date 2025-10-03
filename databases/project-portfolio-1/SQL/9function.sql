CREATE OR REPLACE FUNCTION similar_movies(p_title_id VARCHAR(20), p_limit INT DEFAULT 20)
RETURNS TABLE (sim_title_id VARCHAR(20), primary_title VARCHAR(500), jaccard_genre FLOAT)
LANGUAGE sql
AS $$
WITH base AS (
  SELECT ARRAY_AGG(g.genre ORDER BY g.genre) AS gset
  FROM genre g
  WHERE g.title_id = p_title_id
),
cand AS (
  SELECT t.id, t.primary_title, ARRAY_AGG(g.genre ORDER BY g.genre) AS gset
  FROM title t
  JOIN genre g ON g.title_id = t.id
  WHERE t.id <> p_title_id
  GROUP BY t.id, t.primary_title
)
SELECT
  c.id, c.primary_title,
  CASE
    WHEN cardinality( (SELECT ARRAY(SELECT DISTINCT x FROM unnest(b.gset) x
                                    UNION SELECT DISTINCT y FROM unnest(c.gset) y)) ) = 0
    THEN 0
    ELSE
      cardinality( (SELECT ARRAY(SELECT DISTINCT x FROM unnest(b.gset) x
                                 INTERSECT SELECT DISTINCT y FROM unnest(c.gset) y)) )::float
      /
      cardinality( (SELECT ARRAY(SELECT DISTINCT x FROM unnest(b.gset) x
                                 UNION    SELECT DISTINCT y FROM unnest(c.gset) y)) )::float
  END AS jaccard_genre
FROM base b CROSS JOIN cand c
ORDER BY jaccard_genre DESC, c.primary_title
LIMIT p_limit;
$$;