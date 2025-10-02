-- 1-D.6 Finding co-players

-- target tables: actor, person (for names)

CREATE OR REPLACE FUNCTION find_coplayers(actor_name TEXT)
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

-- 1-D.7 Name rating

-- create new table to store the name ratings for the person (actors only)
-- I think rating is not necessary for other crew members, perhaps only writers or directors.
-- but that can be added later in case!

CREATE TABLE person_rating (
    person_id VARCHAR(10) PRIMARY KEY REFERENCES person(id) ON DELETE CASCADE,
    weighted_rating NUMERIC(3,2)
);

-- this data is stored in its own table (not to pollute the rest of the DB with data that won't be used frequently)
-- so to access it, we have to query the table by joining it with person or actor in case we need other info on the actors

CREATE OR REPLACE FUNCTION calculate_actor_ratings()
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
)
LANGUAGE plpgsql 
AS $$
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
$$;


-- 1-D.11 Exact-match querying

-- looking for word matches so only need tconst and word from wi
-- ALL the argument keyword must be matched!
CREATE OR REPLACE FUNCTION exact_match_query(keywords TEXT[])
RETURNS TABLE (
    title_id VARCHAR(10),
    primary_title TEXT
)
LANGUAGE plpgsql 
AS $$
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
$$;
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
)
LANGUAGE plpgsql 
AS $$
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
$$;

-- same usage as 11

-- 1-D.13 Words-to-words querying
-- return a ranked list of other words that appear in the matching titles,
-- weighted by the frequency of their appearance 
-- or a co-occurrence analysis using the wi

CREATE OR REPLACE FUNCTION word_to_words_query(keywords TEXT[])
RETURNS TABLE (
    word TEXT,
    frequency INT
)
LANGUAGE plpgsql 
AS $$
BEGIN
    RETURN QUERY
    WITH matching_titles AS (
        -- find all titles matching >= one keyword
        SELECT DISTINCT tconst
        FROM wi
        WHERE word = ANY(keywords)
    ),
    word_counts AS (
        -- save all words from matching titles and count frequency
        SELECT wi.word, COUNT(*) AS frequency
        FROM wi
        JOIN matching_titles mt ON wi.tconst = mt.tconst
        GROUP BY wi.word
    )
    -- return top 20 words by frequency
    SELECT word, frequency
    FROM word_counts
    ORDER BY frequency DESC, word
    -- 20 for simplicity, there would be too many results without limit
    LIMIT 20;
END;
$$;

-- same usage as 11, 12





