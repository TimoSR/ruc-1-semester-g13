DROP TABLE IF EXISTS genre  CASCADE;
DROP TABLE IF EXISTS rating CASCADE;
DROP TABLE IF EXISTS title  CASCADE;

CREATE TABLE title (
    id VARCHAR(20) PRIMARY KEY,           
    title_type VARCHAR(50) NOT NULL,
    primary_title VARCHAR(500) NOT NULL,
    original_title VARCHAR(500),
    is_adult BOOLEAN DEFAULT FALSE NOT NULL,
    start_year INT,
    end_year INT,
    runtime_minutes INT,
    poster_url TEXT,      
    plot TEXT              
);

CREATE TABLE rating (
    title_id VARCHAR(20) PRIMARY KEY REFERENCES title(id) ON DELETE CASCADE,
    average_rating FLOAT CHECK (average_rating BETWEEN 0 AND 10),
    num_votes INT CHECK (num_votes >= 0)
);

CREATE TABLE genre (
    title_id VARCHAR(20) NOT NULL REFERENCES title(id) ON DELETE CASCADE,
    genre VARCHAR(50) NOT NULL,
    PRIMARY KEY (title_id, genre)
);


--ignore above




2

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


3

CREATE OR REPLACE FUNCTION rate(p_profile_id INT, p_title_id VARCHAR(20), p_rate INT)
RETURNS TABLE (title_id VARCHAR(20), average_rating FLOAT, num_votes INT)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  INSERT INTO rating(title_id, average_rating, num_votes)
  VALUES (p_title_id, p_rate::float, 1)
  ON CONFLICT ON CONSTRAINT rating_pkey   -- ambiguity fix but not sure if we need this but i needed to do it on chiaras functions to make it work in my db
  DO UPDATE SET
    average_rating = ((rating.average_rating * rating.num_votes) + EXCLUDED.average_rating)
                     / (rating.num_votes + 1),
    num_votes      = rating.num_votes + 1
  RETURNING rating.title_id, rating.average_rating, rating.num_votes;
END;
$$;

9

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
