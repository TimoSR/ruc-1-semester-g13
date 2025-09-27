-- ===========================
-- USERS & PROFILES
-- ===========================
CREATE TABLE IF NOT EXISTS profile (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
);

CREATE TABLE IF NOT EXISTS search_history (
    id SERIAL PRIMARY KEY,
    profile_id INT NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
    search_query TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);