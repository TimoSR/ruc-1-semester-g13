--function that searches for persons(like actors) by substrings

CREATE OR REPLACE FUNCTION find_person_by_name(search_term varchar)
RETURNS TABLE (
person_id varchar(50),
name varchar(50)
) AS $$
BEGIN
RETURN QUERY
SELECT p.person_id, p.name
FROM person p
WHERE p.name ILIKE '%' || search_term || '%'   --case-insensitive
ORDER BY p.name
LIMIT 1;
END;
$$ LANGUAGE plpgsql;


--Function that:
--Accepts a person’s name and an optional max word count.
--Finds all titles related to that person via the wi table.
--Extracts and counts individual words from those titles.
--Returns the top words ordered by frequency

CREATE OR REPLACE FUNCTION person_words(
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

