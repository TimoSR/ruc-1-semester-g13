-- B2_build_movie_db.sql

-- ============================================
-- STEP 1: DROP EXISTING TABLES (for repeatability)
-- ============================================
DROP TABLE IF EXISTS movie_db.actor CASCADE;
DROP TABLE IF EXISTS movie_db.crew CASCADE;
DROP TABLE IF EXISTS movie_db.person_profession CASCADE;
DROP TABLE IF EXISTS movie_db.person_known_for CASCADE;
DROP TABLE IF EXISTS movie_db.person CASCADE;
DROP TABLE IF EXISTS movie_db.rating CASCADE;
DROP TABLE IF EXISTS movie_db.also_known_as CASCADE;
DROP TABLE IF EXISTS movie_db.genre CASCADE;
DROP TABLE IF EXISTS movie_db.episode CASCADE;
DROP TABLE IF EXISTS movie_db.title CASCADE;

-- ============================================
-- STEP 2: CREATE NEW SCHEMA TABLES
-- ============================================

CREATE TABLE movie_db.title (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legacy_id VARCHAR(20) UNIQUE NOT NULL,   -- IMDb tconst
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

CREATE TABLE movie_db.rating (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    average_rating FLOAT CHECK (average_rating BETWEEN 0 AND 10),
    num_votes INT CHECK (num_votes >= 0)
);

CREATE TABLE movie_db.genre (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    genre VARCHAR(50) NOT NULL
);

CREATE TABLE movie_db.episode (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES movie_db.title(id),
    season_number INT,
    episode_number INT
);

CREATE TABLE movie_db.also_known_as (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    list_order INTEGER,
    title TEXT,
    region VARCHAR(10),
    language VARCHAR(10),
    types VARCHAR(256),
    attributes VARCHAR(256),
    is_original_title BOOLEAN
);

CREATE TABLE movie_db.person (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legacy_id VARCHAR(20) UNIQUE NOT NULL,   -- IMDb nconst
    primary_name VARCHAR(100) NOT NULL,               
    birth_year INT,
    death_year INT
);

CREATE TABLE movie_db.person_known_for (
    person_id UUID REFERENCES movie_db.person(id) ON DELETE CASCADE,
    title_id UUID REFERENCES movie_db.title(id) ON DELETE CASCADE,
    PRIMARY KEY (person_id, title_id)
);

CREATE TABLE movie_db.person_profession (
    person_id UUID REFERENCES movie_db.person(id) ON DELETE CASCADE,
    profession VARCHAR(256),
    PRIMARY KEY (person_id, profession)
);

CREATE TABLE movie_db.crew (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID REFERENCES movie_db.title(id) ON DELETE CASCADE,
    person_id UUID REFERENCES movie_db.person(id) ON DELETE CASCADE,
    category VARCHAR(50),
    job TEXT,
    credit_order INTEGER
);

CREATE TABLE movie_db.actor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID REFERENCES movie_db.title(id) ON DELETE CASCADE,
    person_id UUID REFERENCES movie_db.person(id) ON DELETE CASCADE,
    character_name TEXT,
    credit_order INTEGER
);

-- ============================================
-- FUNCTIONS (API schema)
-- ============================================

CREATE OR REPLACE FUNCTION api.string_search(p_profile_id INT, p_query TEXT)
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

CREATE OR REPLACE FUNCTION api.rate(p_profile_id INT, p_title_id VARCHAR(20), p_rate INT)
RETURNS TABLE (title_id VARCHAR(20), average_rating FLOAT, num_votes INT)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  INSERT INTO rating(title_id, average_rating, num_votes)
  VALUES (p_title_id, p_rate::float, 1)
  ON CONFLICT ON CONSTRAINT rating_pkey   -- undgår ambiguity
  DO UPDATE SET
    average_rating = ((rating.average_rating * rating.num_votes) + EXCLUDED.average_rating)
                     / (rating.num_votes + 1),
    num_votes      = rating.num_votes + 1
  RETURNING rating.title_id, rating.average_rating, rating.num_votes;
END;
$$;

CREATE OR REPLACE FUNCTION api.find_person_by_name(search_term TEXT)
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

CREATE OR REPLACE FUNCTION api.find_coplayers(actor_name TEXT)
RETURNS TABLE (
    person_id VARCHAR(10),
    primary_name TEXT,
    frequency INT
)
LANGUAGE plpgsql 
AS $$
BEGIN
    RETURN QUERY
    -- find the person_id of actor from their name
    WITH target_actor AS (
        SELECT id AS person_id
        FROM person
        WHERE primary_name = actor_name
        LIMIT 1
    ),
    -- find all the movies the actor worked in
    target_titles AS (
        SELECT a.title_id
        FROM actor a
        JOIN target_actor t ON a.person_id = t.person_id
    ),
    -- count how many times each other actor is in the same titles 
    co_actors AS (
        SELECT a.person_id, COUNT(*) AS freq
        FROM actor a
        JOIN target_titles tt ON a.title_id = tt.title_id
        JOIN target_actor t ON a.person_id <> t.person_id
        GROUP BY a.person_id
    )
    -- join with person to return their names, sorted by frequency
    SELECT p.id, p.primary_name, c.freq
    FROM co_actors c
    JOIN person p ON p.id = c.person_id
    ORDER BY c.freq DESC, p.primary_name;
END;
$$;

CREATE OR REPLACE FUNCTION api.calculate_actor_ratings()
RETURNS void
LANGUAGE plpgsql 
AS $$
BEGIN
    -- clear old ratings
    DELETE FROM person_rating;

    -- update ratings
    INSERT INTO person_rating (person_id, weighted_rating)
    SELECT 
        a.person_id,
        ROUND(SUM(r.average_rating * r.num_votes)::NUMERIC / NULLIF(SUM(r.num_votes),0), 2) AS weighted_rating
    FROM actor a
    JOIN rating r ON a.title_id = r.title_id
    GROUP BY a.person_id;
END;
$$;

CREATE OR REPLACE FUNCTION api.get_popular_coplayers(p_actor_name TEXT)
RETURNS TABLE (
    actor_id VARCHAR(20),
    actor_fullname TEXT,
    weighted_rating NUMERIC(5,2)
)
LANGUAGE plpgsql 
AS $$
BEGIN
    RETURN QUERY
    WITH target AS (
        SELECT id AS actor_id
        FROM person
        WHERE primary_name = p_actor_name
        LIMIT 1
    ),
    target_titles AS (
        SELECT a.title_id
        FROM actor a
        JOIN target t ON a.person_id = t.actor_id
    )
    SELECT 
        p.id,
        p.primary_name::text,       -- fix mismatch
        pr.weighted_rating
    FROM actor a
    JOIN target_titles tt ON tt.title_id = a.title_id
    JOIN person p ON p.id = a.person_id
    LEFT JOIN person_rating pr ON pr.person_id = p.id
    JOIN target t ON t.actor_id <> a.person_id
    ORDER BY pr.weighted_rating DESC NULLS LAST, p.primary_name;
END;
$$;

CREATE OR REPLACE FUNCTION api.similar_movies(p_title_id VARCHAR(20), p_limit INT DEFAULT 20)
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

-- Search

CREATE OR REPLACE FUNCTION api.person_words(
  p_person_name VARCHAR(100),
  max_words INT DEFAULT 10
)
RETURNS TABLE (
  word TEXT,
  frequency INT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT wi.word, COUNT(*)::INT AS frequency   -- cast til INT
  FROM person p
  JOIN actor a ON a.person_id = p.id
  JOIN wi ON wi.tconst = a.title_id
  WHERE p.primary_name ILIKE '%' || p_person_name || '%'
    AND length(wi.word) > 2
  GROUP BY wi.word
  ORDER BY frequency DESC
  LIMIT max_words;
END;
$$;

CREATE OR REPLACE FUNCTION api.exact_match_query(keywords TEXT[])
RETURNS TABLE (
    title_id VARCHAR(20),
    primary_title TEXT
)
LANGUAGE plpgsql 
AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.primary_title::TEXT
    FROM title t
    WHERE t.id IN (
        SELECT tconst
        FROM wi
        WHERE lower(word) = ANY(SELECT lower(k) FROM unnest(keywords) k)  -- case-insensitive match
        GROUP BY tconst
        HAVING COUNT(DISTINCT lower(word)) = array_length(keywords,1)
    )
    ORDER BY t.primary_title;
END;

CREATE OR REPLACE FUNCTION api.best_match_query(keywords TEXT[])
RETURNS TABLE (
    title_id VARCHAR(20),
    primary_title TEXT,
    match_count INT
)
LANGUAGE plpgsql 
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.primary_title::TEXT,
        COUNT(DISTINCT wi.word)::INT AS match_count   -- fix: cast til INT
    FROM title t
    JOIN wi ON t.id = wi.tconst
    WHERE lower(wi.word) = ANY(SELECT lower(k) FROM unnest(keywords) k)
    GROUP BY t.id, t.primary_title
    ORDER BY match_count DESC, t.primary_title;
END;
$$;

CREATE OR REPLACE FUNCTION api.structured_string_search(
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

CREATE OR REPLACE FUNCTION word_to_words_query(p_keywords TEXT[])
RETURNS TABLE (
    word TEXT,
    frequency INT
)
LANGUAGE plpgsql 
AS $$
BEGIN
    RETURN QUERY
    WITH matching_titles AS (
        SELECT DISTINCT tconst
        FROM wi
        WHERE wi.word = ANY(p_keywords)
    ),
    word_counts AS (
        SELECT wi.word AS keyword, COUNT(*)::INT AS freq
        FROM wi
        JOIN matching_titles mt ON wi.tconst = mt.tconst
        GROUP BY wi.word
    )
    SELECT keyword, freq
    FROM word_counts
    ORDER BY freq DESC, keyword
    LIMIT 20;
END;
$$;