-- not working
movie=# -- 1-D.8 Popular actors

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
ERROR:  parameter name "actor_name" used more than once
CONTEXT:  compilation of PL/pgSQL function "get_popular_coplayers" near line 1
movie=# 


-- fixed

DROP FUNCTION IF EXISTS get_popular_coplayers(text);

CREATE OR REPLACE FUNCTION get_popular_coplayers(p_actor_name TEXT)
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
