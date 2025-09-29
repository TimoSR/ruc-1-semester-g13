-- B2_build_movie_db.sql

-- ============================================
-- STEP 1: DROP EXISTING TABLES (for repeatability)
-- ============================================
DROP TABLE IF EXISTS actor CASCADE;
DROP TABLE IF EXISTS crew CASCADE;
DROP TABLE IF EXISTS person_profession CASCADE;
DROP TABLE IF EXISTS person_known_for CASCADE;
DROP TABLE IF EXISTS person CASCADE;
DROP TABLE IF EXISTS rating CASCADE;
DROP TABLE IF EXISTS also_known_as CASCADE;
DROP TABLE IF EXISTS genre CASCADE;
DROP TABLE IF EXISTS episode CASCADE;
DROP TABLE IF EXISTS title CASCADE;

-- ============================================
-- STEP 2: CREATE NEW SCHEMA TABLES
-- ============================================

-- Chris
CREATE TABLE title (
    id VARCHAR(20) PRIMARY KEY,           
    title_type VARCHAR(50) NOT NULL,
    primary_title VARCHAR(500) NOT NULL,
    original_title VARCHAR(500),
    is_adult BOOLEAN DEFAULT FALSE NOT NULL,
    start_year CHAR(4),
    end_year CHAR(4),
    runtime_minutes INT,
    poster_url TEXT,      
    plot TEXT              
);

-- Chris
CREATE TABLE rating (
    title_id VARCHAR(20) PRIMARY KEY REFERENCES title(id) ON DELETE CASCADE,
    average_rating FLOAT CHECK (average_rating BETWEEN 0 AND 10),
    num_votes INT CHECK (num_votes >= 0)
);

-- Chris
CREATE TABLE genre (
    title_id VARCHAR(20) NOT NULL REFERENCES title(id) ON DELETE CASCADE,
    genre VARCHAR(50) NOT NULL,
    PRIMARY KEY (title_id, genre)
);

-- Chiara
CREATE TABLE episode (
    title_id VARCHAR(20) PRIMARY KEY,
    parent_id VARCHAR(10),
    season_number INTEGER,
    episode_number INTEGER,
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE
);

-- Chiara
CREATE TABLE also_known_as (
    id SERIAL PRIMARY KEY,
    title_id VARCHAR(20),
    list_order INTEGER,
    title TEXT,
    region VARCHAR(10),
    language VARCHAR(10),
    types TEXT,
    attributes TEXT,
    is_original_title BOOLEAN,
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE
);

-- Mana
CREATE TABLE person (
-- changed person_id > id and name > primary_name
  id VARCHAR(20) PRIMARY KEY,      
  primary_name VARCHAR(100) NOT NULL,               
  birth_year INT,
  death_year INT
);

-- Mana
-- CREATE TABLE person_known_for (
--   person_id VARCHAR(50) REFERENCES person(person_id),
-- --   I would add ON DELETE CASCADE and the reference to the title_id
--   title_id VARCHAR(50),                   
--   PRIMARY KEY (person_id, title_id)
-- );

-- Chiara: reworked version
CREATE TABLE person_known_for (
    person_id VARCHAR(20) REFERENCES person(id) ON DELETE CASCADE,
    title_id VARCHAR(20) REFERENCES title(id) ON DELETE CASCADE,
    PRIMARY KEY (person_id, title_id)
);

-- Chiara
CREATE TABLE person_profession (
    person_id VARCHAR(20) REFERENCES person(id) ON DELETE CASCADE,
    profession TEXT,
    PRIMARY KEY (person_id, profession)
);

-- Chiara
CREATE TABLE crew (
    -- serial ID could be used for order crediting but I left it as is for now
    title_id VARCHAR(20),
    person_id VARCHAR(20),
    category TEXT,
    job TEXT,
    -- renamed ordering to credit_order to make it more clear
    credit_order INTEGER,
    PRIMARY KEY (title_id, person_id, category),
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE,
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

-- Chiara
CREATE TABLE actor (
    title_id VARCHAR(20),
    person_id VARCHAR(20),
    character_name TEXT,
    -- renamed ordering to credit_order to make it more clear
    credit_order INTEGER,
    PRIMARY KEY (title_id, person_id),
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE,
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

-- ============================================
-- STEP 3: MIGRATE DATA FROM SOURCE TABLES
-- ============================================

-- Migrate title data, joining with omdb_data for poster and plot
INSERT INTO title (id, title_type, primary_title, original_title, is_adult, 
                  start_year, end_year, runtime_minutes, poster_url, plot)
SELECT 
    tb.tconst,
    tb.titletype,
    tb.primarytitle,
    tb.originaltitle,
    (tb.isadult = '1')::BOOLEAN,   -- IMDb stores as '0' or '1'
    tb.startyear,
    tb.endyear,
    tb.runtimeminutes,
    od.poster,
    od.plot
FROM title_basics tb
LEFT JOIN omdb_data od ON tb.tconst = od.tconst;

-- DEBUGGING -> Just checking that titles were migrated correctly since the rest depends on it:
SELECT COUNT(*) FROM title;

-- Migrate episode data
INSERT INTO episode (title_id, parent_id, season_number, episode_number)
SELECT 
    tconst,
    parenttconst,
    seasonnumber,
    episodenumber
FROM title_episode
WHERE tconst IN (SELECT id FROM title);

-- Migrate and normalize genres
DO $$
DECLARE
    rec RECORD;
    genre_item TEXT;
BEGIN
    FOR rec IN SELECT tconst, genres FROM title_basics WHERE genres IS NOT NULL
    LOOP
        FOREACH genre_item IN ARRAY string_to_array(rec.genres, ',')
        LOOP
            INSERT INTO genre (title_id, genre)
            VALUES (rec.tconst, TRIM(genre_item))
            ON CONFLICT (title_id, genre) DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- Migrate also known as data
INSERT INTO also_known_as (title_id, list_order, title, region, language, 
                          types, attributes, is_original_title)
SELECT 
    titleid,
    ordering::INTEGER,
    title,
    region,
    language,
    types,
    attributes,
    isoriginaltitle::BOOLEAN
FROM title_akas
WHERE titleid IN (SELECT id FROM title);

-- Migrate ratings
INSERT INTO rating (title_id, average_rating, num_votes)
SELECT 
    tconst,
    NULLIF(averagerating, '\N')::NUMERIC(3,1),
    NULLIF(numvotes, '\N')::INT
FROM title_ratings
WHERE tconst IN (SELECT id FROM title);

-- Migrate person data
INSERT INTO person (id, primary_name, birth_year, death_year)
SELECT 
    nconst,
    primaryname,
    NULLIF(birthyear, '\N')::INT,
    NULLIF(deathyear, '\N')::INT
FROM name_basics;

-- Migrate and normalize person known for titles
DO $$
DECLARE
    rec RECORD;
    title_item TEXT;
BEGIN
    FOR rec IN SELECT nconst, knownfortitles FROM name_basics WHERE knownfortitles IS NOT NULL
    LOOP
        FOREACH title_item IN ARRAY string_to_array(rec.knownfortitles, ',')
        LOOP
            -- Only insert if the title exists in our title table
            IF EXISTS (SELECT 1 FROM title WHERE id = TRIM(title_item)) THEN
                INSERT INTO person_known_for (person_id, title_id)
                VALUES (rec.nconst, TRIM(title_item))
                ON CONFLICT (person_id, title_id) DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- Migrate and normalize person professions
DO $$
DECLARE
    rec RECORD;
    profession_item TEXT;
BEGIN
    FOR rec IN SELECT nconst, primaryprofession FROM name_basics WHERE primaryprofession IS NOT NULL
    LOOP
        FOREACH profession_item IN ARRAY string_to_array(rec.primaryprofession, ',')
        LOOP
            INSERT INTO person_profession (person_id, profession)
            VALUES (rec.nconst, TRIM(profession_item))
            ON CONFLICT (person_id, profession) DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- Migrate crew (directors and writers)
-- First, handle directors
DO $$
DECLARE
    rec RECORD;
    director_item TEXT;
BEGIN
    FOR rec IN SELECT tconst, directors FROM title_crew WHERE directors IS NOT NULL
    LOOP
        FOREACH director_item IN ARRAY string_to_array(NULLIF(rec.directors, '\N'), ',')
        LOOP
            IF EXISTS (SELECT 1 FROM person WHERE id = TRIM(director_item)) 
               AND EXISTS (SELECT 1 FROM title WHERE id = rec.tconst) THEN
                INSERT INTO crew (title_id, person_id, category, job, credit_order)
                VALUES (rec.tconst, TRIM(director_item), 'director', 'Director', NULL)
                ON CONFLICT (title_id, person_id, category) DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- Handle writers
DO $$
DECLARE
    rec RECORD;
    writer_item TEXT;
BEGIN
    FOR rec IN SELECT tconst, writers FROM title_crew WHERE writers IS NOT NULL
    LOOP
        FOREACH writer_item IN ARRAY string_to_array(NULLIF(rec.writers, '\N'), ',')
        LOOP
            IF EXISTS (SELECT 1 FROM person WHERE id = TRIM(writer_item)) 
               AND EXISTS (SELECT 1 FROM title WHERE id = rec.tconst) THEN
                INSERT INTO crew (title_id, person_id, category, job, credit_order)
                VALUES (rec.tconst, TRIM(writer_item), 'writer', 'Writer', NULL)
                ON CONFLICT (title_id, person_id, category) DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- Migrate other crew members from title_principals (excluding actors/actresses)
INSERT INTO crew (title_id, person_id, category, job, credit_order)
SELECT 
    tp.tconst,
    tp.nconst,
    tp.category,
    NULLIF(tp.job, '\N'),
    NULLIF(tp.ordering, '\N')::INT
FROM title_principals tp
WHERE tp.category NOT IN ('actor', 'actress', 'self')
  AND EXISTS (SELECT 1 FROM person WHERE id = tp.nconst)
  AND EXISTS (SELECT 1 FROM title WHERE id = tp.tconst)
ON CONFLICT (title_id, person_id, category) DO NOTHING;

-- Migrate actors/actresses from title_principals
INSERT INTO actor (title_id, person_id, character_name, credit_order)
SELECT 
    tp.tconst,
    tp.nconst,
    NULLIF(tp.characters, '\N'),
    NULLIF(tp.ordering, '\N')::INT
FROM title_principals tp
WHERE tp.category IN ('actor', 'actress', 'self')
  AND EXISTS (SELECT 1 FROM person WHERE id = tp.nconst)
  AND EXISTS (SELECT 1 FROM title WHERE id = tp.tconst)
ON CONFLICT (title_id, person_id) DO NOTHING;

-- ============================================
-- STEP 5: DROP SOURCE TABLES
-- ============================================

-- DROP TABLE IF EXISTS title_akas CASCADE;
-- DROP TABLE IF EXISTS title_basics CASCADE;
-- DROP TABLE IF EXISTS title_crew CASCADE;
-- DROP TABLE IF EXISTS title_episode CASCADE;
-- DROP TABLE IF EXISTS title_principals CASCADE;
-- DROP TABLE IF EXISTS title_ratings CASCADE;
-- DROP TABLE IF EXISTS name_basics CASCADE;
-- DROP TABLE IF EXISTS omdb_data CASCADE;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

SELECT 'Titles migrated:' AS info, COUNT(*) AS count FROM title;
SELECT 'Episodes migrated:' AS info, COUNT(*) AS count FROM episode;
SELECT 'Genres migrated:' AS info, COUNT(*) AS count FROM genre;
SELECT 'Ratings migrated:' AS info, COUNT(*) AS count FROM rating;
SELECT 'Persons migrated:' AS info, COUNT(*) AS count FROM person;
SELECT 'Actors migrated:' AS info, COUNT(*) AS count FROM actor;
SELECT 'Crew migrated:' AS info, COUNT(*) AS count FROM crew;
