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