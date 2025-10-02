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