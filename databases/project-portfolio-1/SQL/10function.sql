-- not working

movie=# CREATE OR REPLACE FUNCTION person_words(
person_name varchar(50),
max_words INT DEFAULT 10
)
RETURNS TABLE (
word TEXT,
frequency INT
) AS $$
BEGIN
RETURN QUERY
SELECT w.word, COUNT(*) AS frequency
FROM (
SELECT unnest(string_to_array(lower(regexp_replace(t.title_name, '[^\w\s]', '', 'g')), ' ')) AS word w
FROM person p
JOIN wi ON p.person_id = wi.person_id
JOIN title t ON wi.title_id = t.title_id
WHERE p.name ILIKE '%' || person_name || '%'
)
WHERE length(w.word) > 2  -- optional: filter out short/common words
GROUP BY w.word
ORDER BY frequency DESC
LIMIT max_words;
END;
$$ LANGUAGE plpgsql;
ERROR:  syntax error at or near "w"
LINE 13: ..._replace(t.title_name, '[^\w\s]', '', 'g')), ' ')) AS word w
                                                                       ^
movie=# 


-- fixed
DROP FUNCTION IF EXISTS person_words(varchar, int);

CREATE OR REPLACE FUNCTION person_words(
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
