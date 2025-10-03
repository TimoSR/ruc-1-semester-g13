-- 13
-- not working

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





-- fixed
DROP FUNCTION IF EXISTS word_to_words_query(TEXT[]);

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