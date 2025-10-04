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
    legacy_id VARCHAR(20) UNIQUE NOT NULL,
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

-- Raw user ratings (future-proof)
CREATE TABLE movie_db.user_rating (
    account_id UUID NOT NULL,
    title_id   UUID NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    rating     INT NOT NULL CHECK (rating BETWEEN 1 AND 10),
    PRIMARY KEY (account_id, title_id)  -- ensures one rating per account/title
);

-- Aggregate ratings (historical + summary)
CREATE TABLE movie_db.rating (
    title_id UUID PRIMARY KEY REFERENCES movie_db.title(id) ON DELETE CASCADE,
    average_rating FLOAT CHECK (average_rating BETWEEN 0 AND 10),
    num_votes INT CHECK (num_votes >= 0) DEFAULT 0
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

CREATE TABLE movie_db.word_index (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legacy_id VARCHAR(20) NOT NULL,
    title_id UUID NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    word TEXT NOT NULL,
    field CHAR(1) NOT NULL,
    lexeme TEXT
);

-- ============================================
-- Indexes
-- ============================================

-- ============================================
-- Indexes
-- ============================================

-- Title: search by primary_title, plot (ILIKE / substring search)
CREATE INDEX idx_title_primary_title_trgm
  ON movie_db.title USING gin (primary_title gin_trgm_ops);

CREATE INDEX idx_title_plot_trgm
  ON movie_db.title USING gin (plot gin_trgm_ops);

-- Title: full-text index alternative (if you use full-text search instead of trigram)
CREATE INDEX idx_title_fulltext
  ON movie_db.title USING gin (to_tsvector('english', primary_title || ' ' || coalesce(plot,'')));

-- User ratings: lookup by account
CREATE INDEX idx_user_rating_account
  ON movie_db.user_rating (account_id);

-- Genre: join by title, filter by genre
CREATE INDEX idx_genre_title
  ON movie_db.genre (title_id);

CREATE INDEX idx_genre_genre
  ON movie_db.genre (genre);

-- Episode: filter by parent_id, season/episode numbers
CREATE INDEX idx_episode_parent
  ON movie_db.episode (parent_id);

CREATE INDEX idx_episode_season
  ON movie_db.episode (season_number, episode_number);

-- Also known as: join by title, search by aka title
CREATE INDEX idx_aka_titleid
  ON movie_db.also_known_as (title_id);

CREATE INDEX idx_aka_title_trgm
  ON movie_db.also_known_as USING gin (title gin_trgm_ops);

-- Person: lookup by name (ILIKE)
CREATE INDEX idx_person_name_trgm
  ON movie_db.person USING gin (primary_name gin_trgm_ops);

-- Person known for / profession
CREATE INDEX idx_person_known_for_title
  ON movie_db.person_known_for (title_id);

CREATE INDEX idx_person_profession
  ON movie_db.person_profession (profession);

-- Actor / Crew: joins on title_id and person_id
CREATE INDEX idx_actor_title
  ON movie_db.actor (title_id);

CREATE INDEX idx_actor_person
  ON movie_db.actor (person_id);

CREATE INDEX idx_crew_title
  ON movie_db.crew (title_id);

CREATE INDEX idx_crew_person
  ON movie_db.crew (person_id);

-- Word index: lookups by word, joins on title
CREATE INDEX idx_word_index_word
  ON movie_db.word_index (lower(word));

CREATE INDEX idx_word_index_title
  ON movie_db.word_index (title_id);

-- Optional: trigram index if you do fuzzy searches on words
CREATE INDEX idx_word_index_word_trgm
  ON movie_db.word_index USING gin (word gin_trgm_ops);

-- ============================================
-- FUNCTIONS (API schema)
-- ============================================

CREATE OR REPLACE FUNCTION api.add_user_title_rating(
    in_account_id UUID,
    in_title_id   UUID,
    in_rate       INT
)
RETURNS TABLE (
    out_title_id UUID,
    average_rating DOUBLE PRECISION,
    num_votes INT
)
LANGUAGE plpgsql
AS $$
BEGIN
  -- Store or update the individual vote if we have an account
  IF in_account_id IS NOT NULL THEN
    INSERT INTO movie_db.user_rating (account_id, title_id, rating)
    VALUES (in_account_id, in_title_id, in_rate)
    ON CONFLICT (account_id, title_id)
    DO UPDATE SET rating = EXCLUDED.rating;
  END IF;

  -- Recalculate/update the aggregate rating
  RETURN QUERY
  INSERT INTO movie_db.rating (title_id, average_rating, num_votes)
  SELECT ur.title_id, AVG(ur.rating)::DOUBLE PRECISION, COUNT(*)::INT
  FROM movie_db.user_rating ur
  WHERE ur.title_id = in_title_id
  GROUP BY ur.title_id
  ON CONFLICT (title_id) DO UPDATE
    SET average_rating = EXCLUDED.average_rating,
        num_votes      = EXCLUDED.num_votes
  RETURNING rating.title_id AS out_title_id, 
            rating.average_rating, 
            rating.num_votes;
END;
$$;

CREATE OR REPLACE FUNCTION api.get_person_by_name(search_term TEXT)
RETURNS TABLE (
  person_id UUID,
  name      TEXT
)
LANGUAGE sql
AS $$
  SELECT p.id, p.primary_name
  FROM movie_db.person p
  WHERE p.primary_name ILIKE '%' || search_term || '%'
  ORDER BY p.primary_name
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION api.get_coplayers(p_actor_name TEXT)
RETURNS TABLE (
    person_id UUID,
    primary_name TEXT,
    frequency BIGINT
)
LANGUAGE plpgsql 
AS $$
BEGIN
    RETURN QUERY
    WITH target_actor AS (
        SELECT p.id AS person_id
        FROM movie_db.person p
        WHERE p.primary_name = p_actor_name
        LIMIT 1
    ),
    target_titles AS (
        SELECT a.title_id
        FROM movie_db.actor a
        JOIN target_actor t ON a.person_id = t.person_id
    ),
    co_actors AS (
        SELECT a.person_id, COUNT(*) AS freq
        FROM movie_db.actor a
        JOIN target_titles tt ON a.title_id = tt.title_id
        JOIN target_actor t ON a.person_id <> t.person_id
        GROUP BY a.person_id
    )
    SELECT p.id, p.primary_name::TEXT, c.freq
    FROM co_actors c
    JOIN movie_db.person p ON p.id = c.person_id
    ORDER BY c.freq DESC, p.primary_name;
END;
$$;

-- As it often needs to be calculated I think it could be nice as a view
CREATE MATERIALIZED VIEW movie_db.get_actor_avg_title_rating
AS
SELECT 
    a.person_id,
    ROUND(SUM(r.average_rating * r.num_votes)::NUMERIC / NULLIF(SUM(r.num_votes), 0), 2) AS weighted_rating
FROM movie_db.actor a
JOIN movie_db.rating r ON a.title_id = r.title_id
GROUP BY a.person_id
WITH DATA;

CREATE OR REPLACE FUNCTION api.get_popular_co_actors(p_actor_name TEXT)
RETURNS TABLE (
    actor_id UUID,
    actor_fullname TEXT,
    weighted_rating NUMERIC(5,2)
)
LANGUAGE sql
AS $$
  WITH target AS (
      SELECT id AS actor_id
      FROM movie_db.person
      WHERE primary_name = p_actor_name
      LIMIT 1
  ),
  target_titles AS (
      SELECT a.title_id
      FROM movie_db.actor a
      JOIN target t ON a.person_id = t.actor_id
  )
  SELECT 
      p.id,
      p.primary_name,
      ar.weighted_rating
  FROM movie_db.actor a
  JOIN target_titles tt ON tt.title_id = a.title_id
  JOIN movie_db.person p ON p.id = a.person_id
  LEFT JOIN movie_db.get_actor_avg_title_rating ar 
         ON ar.person_id = p.id
  JOIN target t ON t.actor_id <> a.person_id
  ORDER BY ar.weighted_rating DESC NULLS LAST, p.primary_name;
$$;

CREATE OR REPLACE FUNCTION api.get_similar_movies(p_title_id UUID, p_limit INT DEFAULT 20)
RETURNS TABLE (sim_title_id UUID, primary_title VARCHAR(500), jaccard_genre FLOAT)
LANGUAGE sql
AS $$
WITH base AS (
  SELECT ARRAY_AGG(g.genre ORDER BY g.genre) AS gset
  FROM movie_db.genre g
  WHERE g.title_id = p_title_id
),
cand AS (
  SELECT t.id, t.primary_title, ARRAY_AGG(g.genre ORDER BY g.genre) AS gset
  FROM movie_db.title t
  JOIN movie_db.genre g ON g.title_id = t.id
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


-- ============================================
-- Search FUNCTIONS (API schema)
-- ============================================



-- New solution Full-text (tsvector + GIN)
-- Pros: understands lexemes, supports stemming, ranking, boolean operators.
-- Cons: no arbitrary substring matching (“ero” won’t find “hero”).

-- Old Solution
-- Trigram (ILIKE with gin_trgm_ops)
-- Pros: works like substring search.
-- Cons: no stemming, no ranking.
-- Example: %hero% matches “superhero”.
CREATE OR REPLACE FUNCTION api.string_search_title(p_query TEXT)
RETURNS TABLE (
    title_id UUID,
    primary_title VARCHAR(500)
)
LANGUAGE sql
AS $$
    SELECT t.id, t.primary_title
    FROM movie_db.title t
    WHERE to_tsvector('english', t.primary_title || ' ' || coalesce(t.plot, ''))
          @@ plainto_tsquery('english', p_query)
    ORDER BY ts_rank(
              to_tsvector('english', t.primary_title || ' ' || coalesce(t.plot, '')),
              plainto_tsquery('english', p_query)
             ) DESC;
$$;

CREATE OR REPLACE FUNCTION api.structured_string_search(
  p_title_q  TEXT,
  p_plot_q   TEXT,
  p_char_q   TEXT,
  p_person_q TEXT
)
RETURNS TABLE (
    title_id UUID,
    primary_title VARCHAR(500)
)
LANGUAGE sql
AS $$
  SELECT DISTINCT t.id, t.primary_title
  FROM movie_db.title t
  LEFT JOIN movie_db.actor a   ON a.title_id = t.id
  LEFT JOIN movie_db.person p  ON p.id = a.person_id
  WHERE (p_title_q  IS NULL OR t.primary_title ILIKE '%' || p_title_q  || '%')
    AND (p_plot_q   IS NULL OR t.plot          ILIKE '%' || p_plot_q   || '%')
    AND (p_char_q   IS NULL OR a.character_name ILIKE '%' || p_char_q  || '%')
    AND (p_person_q IS NULL OR p.primary_name  ILIKE '%' || p_person_q || '%')
  ORDER BY t.primary_title;
$$;

---

CREATE OR REPLACE FUNCTION api.person_words(
  p_person_name TEXT,
  max_words INT DEFAULT 10
)
RETURNS TABLE (
  word TEXT,
  frequency INT
)
LANGUAGE sql
AS $$
  SELECT wi.word, COUNT(*)::INT AS frequency
  FROM movie_db.person p
  JOIN movie_db.actor a ON a.person_id = p.id
  JOIN movie_db.word_index wi ON wi.title_id = a.title_id
  WHERE p.primary_name ILIKE '%' || p_person_name || '%'
    AND length(wi.word) > 2
  GROUP BY wi.word
  ORDER BY frequency DESC
  LIMIT max_words;
$$;

CREATE OR REPLACE FUNCTION api.exact_match_query(keywords TEXT[])
RETURNS TABLE (
    title_id UUID,
    primary_title TEXT
)
LANGUAGE sql 
AS $$
  SELECT t.id, t.primary_title
  FROM movie_db.title t
  WHERE t.id IN (
      SELECT wi.title_id
      FROM movie_db.word_index wi
      WHERE lower(wi.word) = ANY(
          SELECT lower(k) FROM unnest(keywords) k
      )
      GROUP BY wi.title_id
      HAVING COUNT(DISTINCT lower(wi.word)) = array_length(keywords,1)
  )
  ORDER BY t.primary_title;
$$;

CREATE OR REPLACE FUNCTION api.best_match_query(keywords TEXT[])
RETURNS TABLE (
    title_id UUID,
    primary_title TEXT,
    match_count INT
)
LANGUAGE sql 
AS $$
  SELECT 
      t.id,
      t.primary_title,
      COUNT(DISTINCT wi.word)::INT AS match_count
  FROM movie_db.title t
  JOIN movie_db.word_index wi ON t.id = wi.title_id
  WHERE lower(wi.word) = ANY(
      SELECT lower(k) FROM unnest(keywords) k
  )
  GROUP BY t.id, t.primary_title
  ORDER BY match_count DESC, t.primary_title;
$$;

CREATE OR REPLACE FUNCTION api.word_to_words_query(p_keywords TEXT[], p_limit INT DEFAULT 20)
RETURNS TABLE (
    word TEXT,
    frequency INT
)
LANGUAGE sql 
AS $$
  WITH matching_titles AS (
      SELECT DISTINCT wi.title_id
      FROM movie_db.word_index wi
      WHERE wi.word = ANY(p_keywords)
  ),
  word_counts AS (
      SELECT wi.word AS keyword, COUNT(*)::INT AS freq
      FROM movie_db.word_index wi
      JOIN matching_titles mt ON wi.title_id = mt.title_id
      GROUP BY wi.word
  )
  SELECT keyword, freq
  FROM word_counts
  ORDER BY freq DESC, keyword
  LIMIT p_limit;
$$;