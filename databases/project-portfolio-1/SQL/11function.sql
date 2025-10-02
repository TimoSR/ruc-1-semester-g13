-- not working
-- 1-D.11 Exact-match querying -- looking for word matches so only need tconst and word from wi -- ALL the argument keyword must be matched! CREATE OR REPLACE FUNCTION exact_match_query(keywords TEXT[]) RETURNS TABLE ( title_id VARCHAR(10), primary_title TEXT ) LANGUAGE plpgsql AS $$ BEGIN RETURN QUERY SELECT t.id, t.primary_title FROM title t WHERE t.id IN ( SELECT tconst FROM wi WHERE word = ANY(keywords) GROUP BY tconst HAVING COUNT(DISTINCT word) = array_length(keywords,1) ) ORDER BY t.primary_title; END; $$; -- to use it: SELECT * FROM exact_match_query(ARRAY['star', 'wars']);

-- fixed

-- Opret fixet version med cast
CREATE OR REPLACE FUNCTION exact_match_query(keywords TEXT[])
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
$$;