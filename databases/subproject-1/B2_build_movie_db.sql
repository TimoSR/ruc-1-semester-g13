-- B2_build_movie_db.sql
-- Migration script from IMDb source tables to new Movie Data Model
-- This script can be run repeatedly - it drops and recreates all tables

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

-- Title table (main entity for all titles)
CREATE TABLE title (
    id VARCHAR(10) PRIMARY KEY,
    title_type VARCHAR(50),
    primary_title TEXT,
    original_title TEXT,
    is_adult BOOLEAN,
    start_year INTEGER,
    end_year INTEGER,
    runtime_minutes INTEGER,
    poster_url TEXT,
    plot TEXT
);

-- Episode table (for TV episodes)
CREATE TABLE episode (
    title_id VARCHAR(10) PRIMARY KEY,
    parent_id VARCHAR(10),
    season_number INTEGER,
    episode_number INTEGER,
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE
);

-- Genre table (normalized from comma-separated values)
CREATE TABLE genre (
    title_id VARCHAR(10),
    genre VARCHAR(100),
    PRIMARY KEY (title_id, genre),
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE
);

-- Also Known As table
CREATE TABLE also_known_as (
    id SERIAL PRIMARY KEY,
    title_id VARCHAR(10),
    list_order INTEGER,
    title TEXT,
    region VARCHAR(10),
    language VARCHAR(10),
    types TEXT,
    attributes TEXT,
    is_original_title BOOLEAN,
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE
);

-- Rating table
CREATE TABLE rating (
    title_id VARCHAR(10) PRIMARY KEY,
    average_rating NUMERIC(3,1),
    num_votes INTEGER,
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE
);

-- Person table
CREATE TABLE person (
    id VARCHAR(10) PRIMARY KEY,
    primary_name TEXT,
    birth_year INTEGER,
    death_year INTEGER,
    primary_professions TEXT
);

-- Person Known For table (normalized from comma-separated values)
CREATE TABLE person_known_for (
    person_id VARCHAR(10),
    title_id VARCHAR(10),
    PRIMARY KEY (person_id, title_id),
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE,
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE
);

-- Person Profession table (normalized from comma-separated values)
CREATE TABLE person_profession (
    person_id VARCHAR(10),
    profession TEXT,
    PRIMARY KEY (person_id, profession),
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

-- Crew table (directors, writers, other non-acting crew)
CREATE TABLE crew (
    title_id VARCHAR(10),
    person_id VARCHAR(10),
    category TEXT,
    job TEXT,
    credit_order INTEGER,
    PRIMARY KEY (title_id, person_id, category),
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE,
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

-- Actor table
CREATE TABLE actor (
    title_id VARCHAR(10),
    person_id VARCHAR(10),
    character_name TEXT,
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
    tb.isadult::BOOLEAN,
    tb.startyear::INTEGER,
    tb.endyear::INTEGER,
    tb.runtimeminutes::INTEGER,
    od.poster,
    od.plot
FROM title_basics tb
LEFT JOIN omdb_data od ON tb.tconst = od.tconst;

-- Migrate episode data
INSERT INTO episode (title_id, parent_id, season_number, episode_number)
SELECT 
    tconst,
    parenttconst,
    seasonnumber::INTEGER,
    episodenumber::INTEGER
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
    averagerating::NUMERIC(3,1),
    numvotes::INTEGER
FROM title_ratings
WHERE tconst IN (SELECT id FROM title);

-- Migrate person data
INSERT INTO person (id, primary_name, birth_year, death_year, primary_professions)
SELECT 
    nconst,
    primaryname,
    birthyear::INTEGER,
    deathyear::INTEGER,
    primaryprofession
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
        FOREACH director_item IN ARRAY string_to_array(rec.directors, ',')
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
        FOREACH writer_item IN ARRAY string_to_array(rec.writers, ',')
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
    tp.job,
    tp.ordering::INTEGER
FROM title_principals tp
WHERE tp.category NOT IN ('actor', 'actress', 'self', 'archive_footage', 'archive_sound')
  AND EXISTS (SELECT 1 FROM person WHERE id = tp.nconst)
  AND EXISTS (SELECT 1 FROM title WHERE id = tp.tconst)
ON CONFLICT (title_id, person_id, category) DO NOTHING;

-- Migrate actors/actresses from title_principals
INSERT INTO actor (title_id, person_id, character_name, credit_order)
SELECT 
    tp.tconst,
    tp.nconst,
    tp.characters,
    tp.ordering::INTEGER
FROM title_principals tp
WHERE tp.category IN ('actor', 'actress', 'self')
  AND EXISTS (SELECT 1 FROM person WHERE id = tp.nconst)
  AND EXISTS (SELECT 1 FROM title WHERE id = tp.tconst)
ON CONFLICT (title_id, person_id) DO NOTHING;

-- ============================================
-- STEP 4: CREATE INDEXES FOR PERFORMANCE
-- ============================================

-- Indexes for foreign key lookups
CREATE INDEX idx_episode_parent_id ON episode(parent_id);
CREATE INDEX idx_genre_title_id ON genre(title_id);
CREATE INDEX idx_also_known_as_title_id ON also_known_as(title_id);
CREATE INDEX idx_person_known_for_person_id ON person_known_for(person_id);
CREATE INDEX idx_person_known_for_title_id ON person_known_for(title_id);
CREATE INDEX idx_person_profession_person_id ON person_profession(person_id);
CREATE INDEX idx_crew_title_id ON crew(title_id);
CREATE INDEX idx_crew_person_id ON crew(person_id);
CREATE INDEX idx_actor_title_id ON actor(title_id);
CREATE INDEX idx_actor_person_id ON actor(person_id);

-- Indexes for common queries
CREATE INDEX idx_title_type ON title(title_type);
CREATE INDEX idx_title_start_year ON title(start_year);
CREATE INDEX idx_person_primary_name ON person(primary_name);

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

-- ============================================
-- STEP 6: ANALYZE TABLES FOR QUERY OPTIMIZATION
-- ============================================

ANALYZE title;
ANALYZE episode;
ANALYZE genre;
ANALYZE also_known_as;
ANALYZE rating;
ANALYZE person;
ANALYZE person_known_for;
ANALYZE person_profession;
ANALYZE crew;
ANALYZE actor;

-- ============================================
-- VERIFICATION QUERIES (Optional - uncomment to test)
-- ============================================

-- SELECT 'Titles migrated:' AS info, COUNT(*) AS count FROM title;
-- SELECT 'Episodes migrated:' AS info, COUNT(*) AS count FROM episode;
-- SELECT 'Genres migrated:' AS info, COUNT(*) AS count FROM genre;
-- SELECT 'Ratings migrated:' AS info, COUNT(*) AS count FROM rating;
-- SELECT 'Persons migrated:' AS info, COUNT(*) AS count FROM person;
-- SELECT 'Actors migrated:' AS info, COUNT(*) AS count FROM actor;
-- SELECT 'Crew migrated:' AS info, COUNT(*) AS count FROM crew;