DROP TABLE IF EXISTS genre  CASCADE;
DROP TABLE IF EXISTS rating CASCADE;
DROP TABLE IF EXISTS title  CASCADE;

CREATE TABLE title (
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