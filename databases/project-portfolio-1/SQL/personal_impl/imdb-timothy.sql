-- ===========================
-- USERS & PROFILES
-- ===========================
DROP TABLE IF EXISTS search_history CASCADE;
DROP TABLE IF EXISTS profile CASCADE;

CREATE TABLE profile (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
);

CREATE TABLE search_history (
    id SERIAL PRIMARY KEY,
    profile_id INT NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
    search_query TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ===========================
-- TITLES
-- ===========================
DROP TABLE IF EXISTS episode CASCADE;
DROP TABLE IF EXISTS also_known_as CASCADE;
DROP TABLE IF EXISTS rating CASCADE;
DROP TABLE IF EXISTS genre CASCADE;
DROP TABLE IF EXISTS title CASCADE;

CREATE TABLE title (
    id VARCHAR(20) PRIMARY KEY,
    title_type VARCHAR(50) NOT NULL,
    primary_title VARCHAR(500) NOT NULL,
    original_title VARCHAR(500),
    is_adult BOOLEAN DEFAULT FALSE,
    start_year INT,
    end_year INT,
    runtime_minutes INT,
    poster_url TEXT,
    plot TEXT
);

CREATE TABLE episode (
    id SERIAL PRIMARY KEY,
    parent_id VARCHAR(20) NOT NULL REFERENCES title(id) ON DELETE CASCADE,
    season_number INT,
    episode_number INT
);

CREATE TABLE also_known_as (
    id SERIAL PRIMARY KEY,
    title_id VARCHAR(20) NOT NULL REFERENCES title(id) ON DELETE CASCADE,
    ordering INT,
    title VARCHAR(500) NOT NULL,
    region VARCHAR(10),
    language VARCHAR(10),
    types VARCHAR(100),
    attributes VARCHAR(200),
    is_original_title BOOLEAN DEFAULT FALSE
);

CREATE TABLE rating (
    title_id VARCHAR(20) PRIMARY KEY REFERENCES title(id) ON DELETE CASCADE,
    average_rating FLOAT CHECK (average_rating BETWEEN 0 AND 10),
    num_votes INT CHECK (num_votes >= 0)
);

CREATE TABLE genre (
    title_id VARCHAR(20) NOT NULL REFERENCES title(id) ON DELETE CASCADE,
    genre VARCHAR(50) NOT NULL,
    PRIMARY KEY (title_id, genre)
);

-- ===========================
-- PEOPLE
-- ===========================
DROP TABLE IF EXISTS person_known_for CASCADE;
DROP TABLE IF EXISTS person CASCADE;

CREATE TABLE person (
    id VARCHAR(20) PRIMARY KEY,
    primary_name VARCHAR(255) NOT NULL,
    birth_year INT,
    death_year INT
);

CREATE TABLE person_known_for (
    person_id VARCHAR(20) NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    title_id VARCHAR(20) NOT NULL REFERENCES title(id) ON DELETE CASCADE,
    PRIMARY KEY (person_id, title_id)
);

-- ===========================
-- CREW & ACTORS
-- ===========================
DROP TABLE IF EXISTS actor CASCADE;
DROP TABLE IF EXISTS crew CASCADE;
DROP TABLE IF EXISTS job_category CASCADE;

CREATE TABLE job_category (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    credit_order INT
);

CREATE TABLE crew (
    title_id VARCHAR(20) NOT NULL REFERENCES title(id) ON DELETE CASCADE,
    person_id VARCHAR(20) NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    job_category_id INT NOT NULL REFERENCES job_category(id) ON DELETE CASCADE,
    job_description TEXT,
    PRIMARY KEY (title_id, person_id, job_category_id)
);

CREATE TABLE actor (
    title_id VARCHAR(20) NOT NULL REFERENCES title(id) ON DELETE CASCADE,
    person_id VARCHAR(20) NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    character_name VARCHAR(255),
    credit_order INT,
    is_lead BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (title_id, person_id)
);
