
drop table if exists person cascade;
drop table if exists person_known_for cascade;

CREATE TABLE person (
  person_id VARCHAR(20) PRIMARY KEY,      
  name VARCHAR(100) NOT NULL,               
  birth_year INT,
  death_year INT
);

CREATE TABLE person_known_for (
  person_id VARCHAR(50)REFERENCES person(person_id),
  title_id VARCHAR(50),                   
  PRIMARY KEY (person_id, title_id)
);

INSERT INTO person (person_id, name, birth_year, death_year)
SELECT
nconst,
primaryName,
CASE WHEN trim(birthYear) ~ '^\d+$' THEN birthYear::INT ELSE NULL END,
CASE WHEN trim(deathYear) ~ '^\d+$' THEN deathYear::INT ELSE NULL END
FROM name_basics
ON CONFLICT (person_id) DO NOTHING;

WITH exploded AS (
SELECT nconst AS person_id,                                    --Renames the person identifier for clarity
unnest(string_to_array(knownForTitles, ',')) AS title_id       --unnest(Converts that array into multiple rows)
FROM name_basics                                                --string_to_arry Splits that string into an array of title IDs.
WHERE knownForTitles IS NOT NULL AND knownForTitles != '\N'      --Filters out empty or invalid entries.
)
INSERT INTO person_known_for (person_id, title_id)
SELECT person_id, title_id FROM exploded
ON CONFLICT (person_id, title_id) DO NOTHING;