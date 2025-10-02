-- B2_build_movie_db.sql

-- ============================================
-- STEP 1: DROP EXISTING TABLES (for repeatability)
-- ============================================
DROP TABLE IF EXISTS movie_db.actor CASCADE;
DROP TABLE IF EXISTS movie_db.crew CASCADE;
DROP TABLE IF EXISTS movie_db.person_profession CASCADE;
DROP TABLE IF EXISTS movie_db.person_known_for CASCADE;
DROP TABLE IF EXISTS movie_db.person CASCADE;
DROP TABLE IF EXISTS movie_db.rating CASCADE;
DROP TABLE IF EXISTS movie_db.also_known_as CASCADE;
DROP TABLE IF EXISTS movie_db.genre CASCADE;
DROP TABLE IF EXISTS movie_db.episode CASCADE;
DROP TABLE IF EXISTS movie_db.title CASCADE;

-- ============================================
-- STEP 2: CREATE NEW SCHEMA TABLES
-- ============================================

CREATE TABLE movie_db.title (
    id VARCHAR(20) PRIMARY KEY,           
    title_type VARCHAR(50) NOT NULL,
    primary_title VARCHAR(500) NOT NULL,
    original_title VARCHAR(500),
    is_adult BOOLEAN DEFAULT FALSE NOT NULL,
    start_year INT,
    end_year INT,
    runtime_minutes INT,
    poster_url TEXT,      
    plot TEXT
);

CREATE TABLE movie_db.rating (
    title_id VARCHAR(20) PRIMARY KEY REFERENCES movie_db.title(id) ON DELETE CASCADE,
    average_rating FLOAT CHECK (average_rating BETWEEN 0 AND 10),
    num_votes INT CHECK (num_votes >= 0)
);

CREATE TABLE movie_db.genre (
    title_id VARCHAR(20) NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    genre VARCHAR(50) NOT NULL,
    PRIMARY KEY (title_id, genre)
);

CREATE TABLE movie_db.episode (
    title_id VARCHAR(20) PRIMARY KEY REFERENCES movie_db.title(id) ON DELETE CASCADE,
    parent_id VARCHAR(10) REFERENCES movie_db.title(id),
    season_number INT,
    episode_number INT
);

CREATE TABLE movie_db.also_known_as (
    id SERIAL PRIMARY KEY,
    title_id VARCHAR(20) NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    list_order INTEGER,
    title TEXT,
    region VARCHAR(10),
    language VARCHAR(10),
    types VARCHAR(256),
    attributes VARCHAR(256),
    is_original_title BOOLEAN
);

CREATE TABLE movie_db.person (
  id VARCHAR(20) PRIMARY KEY,      
  primary_name VARCHAR(100) NOT NULL,               
  birth_year INT,
  death_year INT
);

CREATE TABLE movie_db.person_known_for (
    person_id VARCHAR(20) REFERENCES movie_db.person(id) ON DELETE CASCADE,
    title_id VARCHAR(20) REFERENCES movie_db.title(id) ON DELETE CASCADE,
    PRIMARY KEY (person_id, title_id)
);

CREATE TABLE movie_db.person_profession (
    person_id VARCHAR(20) REFERENCES movie_db.person(id) ON DELETE CASCADE,
    profession VARCHAR(256),
    PRIMARY KEY (person_id, profession)
);

CREATE TABLE movie_db.crew (
    title_id VARCHAR(20) REFERENCES movie_db.title(id) ON DELETE CASCADE,
    person_id VARCHAR(20) REFERENCES movie_db.person(id) ON DELETE CASCADE,
    category VARCHAR(50),
    job TEXT,
    credit_order INTEGER,
    PRIMARY KEY (title_id, person_id, category)
);

CREATE TABLE movie_db.actor (
    title_id VARCHAR(20) REFERENCES movie_db.title(id) ON DELETE CASCADE,
    person_id VARCHAR(20) REFERENCES movie_db.person(id) ON DELETE CASCADE,
    character_name TEXT,
    credit_order INTEGER,
    PRIMARY KEY (title_id, person_id)
);

-- ============================================
-- STEP 3: MIGRATE DATA FROM SOURCE TABLES
-- ============================================

INSERT INTO movie_db.title (id, title_type, primary_title, original_title, is_adult, 
                  start_year, end_year, runtime_minutes, poster_url, plot)
SELECT 
    tb.tconst,
    tb.titletype,
    tb.primarytitle,
    tb.originaltitle,
    tb.isadult,
    NULLIF(NULLIF(tb.startyear, '\N'), '')::INT,
    NULLIF(NULLIF(tb.endyear, '\N'), '')::INT,
    tb.runtimeminutes,
    od.poster,
    od.plot
FROM title_basics tb
LEFT JOIN omdb_data od ON tb.tconst = od.tconst;

SELECT COUNT(*) FROM movie_db.title;

INSERT INTO movie_db.episode (title_id, parent_id, season_number, episode_number)
SELECT 
    tconst,
    parenttconst,
    seasonnumber,
    episodenumber
FROM title_episode
WHERE tconst IN (SELECT id FROM movie_db.title);

DO $$
DECLARE
    rec RECORD;
    genre_item TEXT;
BEGIN
    FOR rec IN SELECT tconst, genres FROM title_basics WHERE genres IS NOT NULL
    LOOP
        FOREACH genre_item IN ARRAY string_to_array(rec.genres, ',')
        LOOP
            INSERT INTO movie_db.genre (title_id, genre)
            VALUES (rec.tconst, TRIM(genre_item))
            ON CONFLICT (title_id, genre) DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

INSERT INTO movie_db.also_known_as (title_id, list_order, title, region, language, 
                          types, attributes, is_original_title)
SELECT 
    titleid,
    ordering,
    title,
    region,
    language,
    types,
    attributes,
    isoriginaltitle
FROM title_akas
WHERE titleid IN (SELECT id FROM movie_db.title);

INSERT INTO movie_db.rating (title_id, average_rating, num_votes)
SELECT 
    tconst,
    averagerating,
    numvotes
FROM title_ratings
WHERE tconst IN (SELECT id FROM movie_db.title);

INSERT INTO movie_db.person (id, primary_name, birth_year, death_year)
SELECT 
    nconst,
    primaryname,
    NULLIF(NULLIF(birthyear, '\N'), '')::INT,
    NULLIF(NULLIF(deathyear, '\N'), '')::INT
FROM name_basics;

DO $$
DECLARE
    rec RECORD;
    title_item TEXT;
BEGIN
    FOR rec IN SELECT nconst, knownfortitles FROM name_basics WHERE knownfortitles IS NOT NULL
    LOOP
        FOREACH title_item IN ARRAY string_to_array(rec.knownfortitles, ',')
        LOOP
            IF EXISTS (SELECT 1 FROM movie_db.title WHERE id = TRIM(title_item)) THEN
                INSERT INTO movie_db.person_known_for (person_id, title_id)
                VALUES (rec.nconst, TRIM(title_item))
                ON CONFLICT (person_id, title_id) DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;
END $$;

DO $$
DECLARE
    rec RECORD;
    profession_item TEXT;
BEGIN
    FOR rec IN SELECT nconst, primaryprofession FROM name_basics WHERE primaryprofession IS NOT NULL
    LOOP
        FOREACH profession_item IN ARRAY string_to_array(rec.primaryprofession, ',')
        LOOP
            INSERT INTO movie_db.person_profession (person_id, profession)
            VALUES (rec.nconst, TRIM(profession_item))
            ON CONFLICT (person_id, profession) DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

INSERT INTO movie_db.crew (title_id, person_id, category, job, credit_order)
SELECT 
    tp.tconst,
    tp.nconst,
    tp.category,
    tp.job,
    tp.ordering
FROM title_principals tp
WHERE tp.category NOT IN ('actor', 'actress', 'self')
  AND EXISTS (SELECT 1 FROM movie_db.person WHERE id = tp.nconst)
  AND EXISTS (SELECT 1 FROM movie_db.title WHERE id = tp.tconst)
ON CONFLICT (title_id, person_id, category) DO NOTHING;

INSERT INTO movie_db.actor (title_id, person_id, character_name, credit_order)
SELECT 
    tp.tconst,
    tp.nconst,
    tp.characters,
    tp.ordering
FROM title_principals tp
WHERE tp.category IN ('actor', 'actress', 'self')
  AND EXISTS (SELECT 1 FROM movie_db.person WHERE id = tp.nconst)
  AND EXISTS (SELECT 1 FROM movie_db.title WHERE id = tp.tconst)
ON CONFLICT (title_id, person_id) DO NOTHING;

-- ============================================
-- STEP 5: DROP SOURCE TABLES
-- ============================================
DROP TABLE IF EXISTS title_akas CASCADE;
DROP TABLE IF EXISTS title_basics CASCADE;
DROP TABLE IF EXISTS title_crew CASCADE;
DROP TABLE IF EXISTS title_episode CASCADE;
DROP TABLE IF EXISTS title_principals CASCADE;
DROP TABLE IF EXISTS title_ratings CASCADE;
DROP TABLE IF EXISTS name_basics CASCADE;
DROP TABLE IF EXISTS omdb_data CASCADE;