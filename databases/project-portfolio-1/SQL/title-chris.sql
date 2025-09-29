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





adsdadssdadasdasdadasdasd

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
  ON CONFLICT ON CONSTRAINT rating_pkey   -- undgår ambiguity
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







1.1
-- Create (returns id)
CREATE OR REPLACE FUNCTION create_user(p_username TEXT, p_password TEXT)
RETURNS INT LANGUAGE sql AS $$
  INSERT INTO profile(username, password)
  VALUES (p_username, p_password)
  ON CONFLICT (username) DO UPDATE SET username = EXCLUDED.username
  RETURNING id;
$$;

-- Find by username (returns id)
CREATE OR REPLACE FUNCTION find_user(p_username TEXT)
RETURNS INT LANGUAGE sql AS $$
  SELECT id FROM profile WHERE username = p_username LIMIT 1;
$$;

-- Change password
CREATE OR REPLACE FUNCTION change_password(p_profile_id INT, p_new TEXT)
RETURNS VOID LANGUAGE sql AS $$
  UPDATE profile SET password = p_new WHERE id = p_profile_id;
$$;

-- Delete user (CASCADE rydder bookmarks/notes/history)
CREATE OR REPLACE FUNCTION delete_user(p_profile_id INT)
RETURNS VOID LANGUAGE sql AS $$
  DELETE FROM profile WHERE id = p_profile_id;
$$;


1.2
-- Titles
CREATE OR REPLACE FUNCTION add_bookmark_title(p_profile_id INT, p_title_id VARCHAR(20))
RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO bookmark_title(profile_id, title_id) VALUES (p_profile_id, p_title_id)
  ON CONFLICT DO NOTHING;
$$;

CREATE OR REPLACE FUNCTION remove_bookmark_title(p_profile_id INT, p_title_id VARCHAR(20))
RETURNS VOID LANGUAGE sql AS $$
  DELETE FROM bookmark_title WHERE profile_id = p_profile_id AND title_id = p_title_id;
$$;

CREATE OR REPLACE FUNCTION list_bookmarked_titles(p_profile_id INT)
RETURNS TABLE (title_id VARCHAR(20), primary_title VARCHAR(500))
LANGUAGE sql AS $$
  SELECT bt.title_id, t.primary_title
  FROM bookmark_title bt JOIN title t ON t.id = bt.title_id
  WHERE bt.profile_id = p_profile_id
  ORDER BY t.primary_title;
$$;

-- Persons
CREATE OR REPLACE FUNCTION add_bookmark_person(p_profile_id INT, p_person_id VARCHAR(20))
RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO bookmark_person(profile_id, person_id) VALUES (p_profile_id, p_person_id)
  ON CONFLICT DO NOTHING;
$$;

CREATE OR REPLACE FUNCTION remove_bookmark_person(p_profile_id INT, p_person_id VARCHAR(20))
RETURNS VOID LANGUAGE sql AS $$
  DELETE FROM bookmark_person WHERE profile_id = p_profile_id AND person_id = p_person_id;
$$;

CREATE OR REPLACE FUNCTION list_bookmarked_persons(p_profile_id INT)
RETURNS TABLE (person_id VARCHAR(20), primary_name VARCHAR(255))
LANGUAGE sql AS $$
  SELECT bp.person_id, p.primary_name
  FROM bookmark_person bp JOIN person p ON p.id = bp.person_id
  WHERE bp.profile_id = p_profile_id
  ORDER BY p.primary_name;
$$;


1.3
-- Titles
CREATE OR REPLACE FUNCTION set_note_title(p_profile_id INT, p_title_id VARCHAR(20), p_note TEXT)
RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO note_title(profile_id, title_id, note, updated_at)
  VALUES (p_profile_id, p_title_id, p_note, NOW())
  ON CONFLICT (profile_id, title_id)
  DO UPDATE SET note = EXCLUDED.note, updated_at = NOW();
$$;

CREATE OR REPLACE FUNCTION get_note_title(p_profile_id INT, p_title_id VARCHAR(20))
RETURNS TABLE (title_id VARCHAR(20), note TEXT, updated_at TIMESTAMP)
LANGUAGE sql AS $$
  SELECT title_id, note, updated_at
  FROM note_title
  WHERE profile_id = p_profile_id AND title_id = p_title_id;
$$;

CREATE OR REPLACE FUNCTION delete_note_title(p_profile_id INT, p_title_id VARCHAR(20))
RETURNS VOID LANGUAGE sql AS $$
  DELETE FROM note_title WHERE profile_id = p_profile_id AND title_id = p_title_id;
$$;

-- Persons
CREATE OR REPLACE FUNCTION set_note_person(p_profile_id INT, p_person_id VARCHAR(20), p_note TEXT)
RETURNS VOID LANGUAGE sql AS $$
  INSERT INTO note_person(profile_id, person_id, note, updated_at)
  VALUES (p_profile_id, p_person_id, p_note, NOW())
  ON CONFLICT (profile_id, person_id)
  DO UPDATE SET note = EXCLUDED.note, updated_at = NOW();
$$;

CREATE OR REPLACE FUNCTION get_note_person(p_profile_id INT, p_person_id VARCHAR(20))
RETURNS TABLE (person_id VARCHAR(20), note TEXT, updated_at TIMESTAMP)
LANGUAGE sql AS $$
  SELECT person_id, note, updated_at
  FROM note_person
  WHERE profile_id = p_profile_id AND person_id = p_person_id;
$$;

CREATE OR REPLACE FUNCTION delete_note_person(p_profile_id INT, p_person_id VARCHAR(20))
RETURNS VOID LANGUAGE sql AS $$
  DELETE FROM note_person WHERE profile_id = p_profile_id AND person_id = p_person_id;
$$;

1.4
-- Bookmarks hentes via list_* functions ovenfor

-- Search history
CREATE OR REPLACE FUNCTION get_search_history(p_profile_id INT, p_limit INT DEFAULT 50)
RETURNS TABLE (searched_at TIMESTAMP, query TEXT)
LANGUAGE sql AS $$
  SELECT created_at, search_query
  FROM search_history
  WHERE profile_id = p_profile_id
  ORDER BY created_at DESC
  LIMIT p_limit;
$$;

-- Rating history (forudsætter rating_history tabellen)
CREATE OR REPLACE FUNCTION get_rating_history(p_profile_id INT, p_limit INT DEFAULT 50)
RETURNS TABLE (rated_at TIMESTAMP, title_id VARCHAR(20), rate INT, primary_title VARCHAR(500))
LANGUAGE sql AS $$
  SELECT rh.rated_at, rh.title_id, rh.rate, t.primary_title
  FROM rating_history rh LEFT JOIN title t ON t.id = rh.title_id
  WHERE rh.profile_id = p_profile_id
  ORDER BY rh.rated_at DESC
  LIMIT p_limit;
$$;









4
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
  -- param-variabler + tæller til EXECUTE ... USING
  p1 TEXT; p2 TEXT; p3 TEXT; p4 TEXT;
  n  INT := 0;
BEGIN
  -- log i search_history (kompakt tekst)
  INSERT INTO search_history(profile_id, search_query)
  VALUES (p_profile_id,
          CONCAT_WS(' | ',
            NULLIF('title='||COALESCE(p_title_q,''), 'title='),
            NULLIF('plot='||COALESCE(p_plot_q,''), 'plot='),
            NULLIF('char='||COALESCE(p_char_q,''), 'char='),
            NULLIF('person='||COALESCE(p_person_q,''), 'person=')
          )
  );

  -- tjek om tabeller findes
  SELECT EXISTS (
           SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
           WHERE c.relname='actor' AND n.nspname='public'
         ) INTO v_has_actor;

  SELECT EXISTS (
           SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
           WHERE c.relname='person' AND n.nspname='public'
         ) INTO v_has_person;

  -- join actor/person hvis tilgængelige (for char/person-søgning)
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

  -- character filter (kun hvis actor findes)
  IF (p_char_q IS NOT NULL AND p_char_q <> '') AND v_has_actor THEN
    p3 := '%' || p_char_q || '%'; n := n + 1;
    where_clauses := where_clauses || format(' AND a.character_name ILIKE $%s', n);
  END IF;

  -- person-name filter (kun hvis actor+person findes)
  IF (p_person_q IS NOT NULL AND p_person_q <> '') AND v_has_actor AND v_has_person THEN
    p4 := '%' || p_person_q || '%'; n := n + 1;
    where_clauses := where_clauses || format(' AND p.primary_name ILIKE $%s', n);
  END IF;

  sql := sql || where_clauses || ' ORDER BY t.primary_title';

  -- kør dynamisk med de parametre der faktisk blev brugt
  IF n = 0 THEN
    RETURN QUERY EXECUTE sql;                                -- ingen filtre
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

















-- Chi testede på egen db

-- 1-D.6 Finding co-players (Virker ik)

-- target tables: actor, person (for names)

CREATE OR REPLACE FUNCTION find_coplayers(actor_name TEXT)
RETURNS TABLE (
    person_id VARCHAR(10),
    primary_name TEXT,
    frequency INT
) AS $$
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
$$ LANGUAGE plpgsql;


-- 1-D.7 Name rating (Virker)

-- create new table to store the name ratings for the person (actors only)
-- I think rating is not necessary for other crew members, perhaps only writers or directors.
-- but that can be added later in case!

CREATE TABLE person_rating (
    person_id VARCHAR(10) PRIMARY KEY,
    weighted_rating NUMERIC(3,2),
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

-- this data is stored in its own table (not to pollute the rest of the DB with data that won't be used frequently)
-- so to access it, we have to query the table by joining it with person or actor in case we need other info on the actors

CREATE OR REPLACE FUNCTION calculate_actor_ratings()
RETURNS void AS $$
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
$$ LANGUAGE plpgsql;


-- 1-D.8 Popular actors

-- I picked OPTION B (a list of popular co-players of a given actor)
-- I think it would be more useful in the app, since the actors associated with a movie are typically
-- sorted according to the importance of the role they have in the movie so this wouldn't make much sense to me.

-- input = actor name
-- output = all their co-players, ordered by popularity

CREATE OR REPLACE FUNCTION get_popular_coplayers(actor_name TEXT)
RETURNS TABLE (
    actor_id VARCHAR(10),
    actor_name TEXT,
    weighted_rating NUMERIC(3,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH target AS (
        SELECT id AS actor_id
        FROM person
        WHERE primary_name = actor_name
        LIMIT 1
    ),
    target_titles AS (
        SELECT a.title_id
        FROM actor a
        JOIN target t ON a.person_id = t.actor_id
    )
    SELECT 
        p.id,
        p.primary_name,
        pr.weighted_rating
    FROM actor a
    JOIN target_titles tt ON tt.title_id = a.title_id
    JOIN person p ON p.id = a.person_id
    LEFT JOIN person_rating pr ON pr.person_id = p.id
    JOIN target t ON t.actor_id <> a.person_id
    ORDER BY pr.weighted_rating DESC NULLS LAST, p.primary_name;
END;
$$ LANGUAGE plpgsql;

-- 1-D.8 Popular actors

-- I picked OPTION B (a list of popular co-players of a given actor)
-- I think it would be more useful in the app, since the actors associated with a movie are typically
-- sorted according to the importance of the role they have in the movie so this wouldn't make much sense to me.

-- input = actor name
-- output = all their co-players, ordered by popularity

CREATE OR REPLACE FUNCTION get_popular_coplayers(actor_name TEXT)
RETURNS TABLE (
    actor_id VARCHAR(10),
    actor_name TEXT,
    weighted_rating NUMERIC(3,2)
) AS $$
BEGIN
    RETURN QUERY
    WITH target AS (
        SELECT id AS actor_id
        FROM person
        WHERE primary_name = actor_name
        LIMIT 1
    ),
    target_titles AS (
        SELECT a.title_id
        FROM actor a
        JOIN target t ON a.person_id = t.actor_id
    )
    SELECT 
        p.id,
        p.primary_name,
        pr.weighted_rating
    FROM actor a
    JOIN target_titles tt ON tt.title_id = a.title_id
    JOIN person p ON p.id = a.person_id
    LEFT JOIN person_rating pr ON pr.person_id = p.id
    JOIN target t ON t.actor_id <> a.person_id
    ORDER BY pr.weighted_rating DESC NULLS LAST, p.primary_name;
END;
$$ LANGUAGE plpgsql;

-- 1-D.11 Exact-match querying

-- looking for word matches so only need tconst and word from wi
-- ALL the argument keyword must be matched!
CREATE OR REPLACE FUNCTION exact_match_query(keywords TEXT[])
RETURNS TABLE (
    title_id VARCHAR(10),
    primary_title TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT t.id, t.primary_title
    FROM title t
    WHERE t.id IN (
        SELECT tconst
        FROM wi
        WHERE word = ANY(keywords)
        GROUP BY tconst
        HAVING COUNT(DISTINCT word) = array_length(keywords,1)
    )
    ORDER BY t.primary_title;
END;
$$ LANGUAGE plpgsql;
-- to use it: SELECT * FROM exact_match_query(ARRAY['star', 'wars']);


-- 1-D.12 Best-match querying

-- similar to 11 but it returns a best-match of the response
-- so each match doesn't need to match ALL the keywords, but it will be ranked higher the more keywords are matched

CREATE OR REPLACE FUNCTION best_match_query(keywords TEXT[])
RETURNS TABLE (
    title_id VARCHAR(10),
    primary_title TEXT,
    -- the higher the match_count, the higher the rank
    match_count INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.primary_title,
        COUNT(DISTINCT wi.word) AS match_count
    FROM title t
    JOIN wi ON t.id = wi.tconst
    WHERE wi.word = ANY(keywords)
    GROUP BY t.id, t.primary_title
    -- no HAVING clause, so it returns titles even if only some keywords are matched
    ORDER BY match_count DESC, t.primary_title;
END;
$$ LANGUAGE plpgsql;

-- same usage as 11

