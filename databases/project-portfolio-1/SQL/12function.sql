-- not working

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

-- fixed
DROP FUNCTION IF EXISTS best_match_query(TEXT[]);

CREATE OR REPLACE FUNCTION best_match_query(keywords TEXT[])
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