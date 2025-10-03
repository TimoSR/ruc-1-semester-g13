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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legacy_id VARCHAR(20) UNIQUE NOT NULL,   -- IMDb tconst
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    average_rating FLOAT CHECK (average_rating BETWEEN 0 AND 10),
    num_votes INT CHECK (num_votes >= 0)
);

CREATE TABLE movie_db.genre (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    genre VARCHAR(50) NOT NULL
);

CREATE TABLE movie_db.episode (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES movie_db.title(id),
    season_number INT,
    episode_number INT
);

CREATE TABLE movie_db.also_known_as (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    list_order INTEGER,
    title TEXT,
    region VARCHAR(10),
    language VARCHAR(10),
    types VARCHAR(256),
    attributes VARCHAR(256),
    is_original_title BOOLEAN
);

CREATE TABLE movie_db.person (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    legacy_id VARCHAR(20) UNIQUE NOT NULL,   -- IMDb nconst
    primary_name VARCHAR(100) NOT NULL,               
    birth_year INT,
    death_year INT
);

CREATE TABLE movie_db.person_known_for (
    person_id UUID REFERENCES movie_db.person(id) ON DELETE CASCADE,
    title_id UUID REFERENCES movie_db.title(id) ON DELETE CASCADE,
    PRIMARY KEY (person_id, title_id)
);

CREATE TABLE movie_db.person_profession (
    person_id UUID REFERENCES movie_db.person(id) ON DELETE CASCADE,
    profession VARCHAR(256),
    PRIMARY KEY (person_id, profession)
);

CREATE TABLE movie_db.crew (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID REFERENCES movie_db.title(id) ON DELETE CASCADE,
    person_id UUID REFERENCES movie_db.person(id) ON DELETE CASCADE,
    category VARCHAR(50),
    job TEXT,
    credit_order INTEGER
);

CREATE TABLE movie_db.actor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title_id UUID REFERENCES movie_db.title(id) ON DELETE CASCADE,
    person_id UUID REFERENCES movie_db.person(id) ON DELETE CASCADE,
    character_name TEXT,
    credit_order INTEGER
);