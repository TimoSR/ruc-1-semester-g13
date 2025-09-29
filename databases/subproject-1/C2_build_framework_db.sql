-- C2_build_framework_db.sql

-- ============================================
-- STEP 1: DROP EXISTING FRAMEWORK TABLES (for repeatability)
-- ============================================
DROP TABLE IF EXISTS bookmark CASCADE;
DROP TABLE IF EXISTS rating_history CASCADE;
DROP TABLE IF EXISTS search_history CASCADE;
DROP TABLE IF EXISTS profile CASCADE;

-- ============================================
-- STEP 2: CREATE FRAMEWORK TABLES
-- ============================================

-- Timothy
CREATE TABLE profile (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL
);

-- Timothy
CREATE TABLE search_history (
    id SERIAL PRIMARY KEY,
    profile_id INT NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
    search_query TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
);

-- Chiara
CREATE TABLE rating_history (
    id SERIAL PRIMARY KEY,
    profile_id INT NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
    title_id VARCHAR(20) NOT NULL REFERENCES title(id) ON DELETE CASCADE,
    rating INT CHECK (rating >= 1 AND rating <= 10),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Chiara
CREATE TABLE bookmark (
    id SERIAL PRIMARY KEY,
    profile_id INT NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
    title_id VARCHAR(20) REFERENCES title(id) ON DELETE CASCADE,
    person_id VARCHAR(20) REFERENCES person(id) ON DELETE CASCADE,
    bookmark_type VARCHAR(20) NOT NULL, -- 'title' or 'person'
    created_at TIMESTAMP DEFAULT NOW(),
    -- Ensure exactly one of title_id or person_id is set
    CONSTRAINT bookmark_type_check CHECK (
        (bookmark_type = 'title' AND title_id IS NOT NULL AND person_id IS NULL) OR
        (bookmark_type = 'person' AND person_id IS NOT NULL AND title_id IS NULL)
    ),
    -- Prevent duplicate bookmarks
    CONSTRAINT unique_user_title_bookmark UNIQUE (user_id, title_id),
    CONSTRAINT unique_user_person_bookmark UNIQUE (user_id, person_id),
);

-- ============================================
-- STEP 3: INSERT TEST DATA (Optional - comment out in production)
-- ============================================

-- Create a test user
-- INSERT INTO "user" (username, password, email) 
-- VALUES ('testuser', 'hashed_password_here', 'test@example.com');


-- ============================================
-- VERIFICATION QUERIES [...]
-- ============================================