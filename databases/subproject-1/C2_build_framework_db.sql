-- C2_build_framework_db.sql
-- Framework Model creation script for user management and interaction tracking
-- This script adds framework tables to an existing Movie Data Model database

-- ============================================
-- STEP 1: DROP EXISTING FRAMEWORK TABLES (for repeatability)
-- ============================================
DROP TABLE IF EXISTS bookmark CASCADE;
DROP TABLE IF EXISTS rating_history CASCADE;
DROP TABLE IF EXISTS search_history CASCADE;
DROP TABLE IF EXISTS "user" CASCADE;

-- ============================================
-- STEP 2: CREATE FRAMEWORK TABLES
-- ============================================

-- User table
-- Note: Using "user" in quotes since USER is a reserved word in PostgreSQL
CREATE TABLE "user" (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Search history table
CREATE TABLE search_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    search_query TEXT NOT NULL,
    search_type VARCHAR(50) DEFAULT 'general', -- 'general', 'structured', 'person', 'exact_match', etc.
    result_count INTEGER DEFAULT 0,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES "user"(id) ON DELETE CASCADE
);

-- Rating history table
CREATE TABLE rating_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title_id VARCHAR(10) NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 10),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Unique constraint to ensure one rating per user per title
    CONSTRAINT unique_user_title_rating UNIQUE (user_id, title_id),
    FOREIGN KEY (user_id) REFERENCES "user"(id) ON DELETE CASCADE,
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE
);

-- Bookmark table
-- Handles both title and person bookmarks with proper constraints
CREATE TABLE bookmark (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title_id VARCHAR(10),
    person_id VARCHAR(10),
    bookmark_type VARCHAR(20) NOT NULL, -- 'title' or 'person'
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- Ensure exactly one of title_id or person_id is set
    CONSTRAINT bookmark_type_check CHECK (
        (bookmark_type = 'title' AND title_id IS NOT NULL AND person_id IS NULL) OR
        (bookmark_type = 'person' AND person_id IS NOT NULL AND title_id IS NULL)
    ),
    -- Prevent duplicate bookmarks
    CONSTRAINT unique_user_title_bookmark UNIQUE (user_id, title_id),
    CONSTRAINT unique_user_person_bookmark UNIQUE (user_id, person_id),
    FOREIGN KEY (user_id) REFERENCES "user"(id) ON DELETE CASCADE,
    FOREIGN KEY (title_id) REFERENCES title(id) ON DELETE CASCADE,
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE
);

-- ============================================
-- STEP 3: CREATE INDEXES FOR PERFORMANCE
-- ============================================

-- User table indexes
CREATE INDEX idx_user_username ON "user"(username);
CREATE INDEX idx_user_email ON "user"(email);
CREATE INDEX idx_user_is_active ON "user"(is_active);

-- Search history indexes
CREATE INDEX idx_search_history_user_id ON search_history(user_id);
CREATE INDEX idx_search_history_timestamp ON search_history(timestamp DESC);
CREATE INDEX idx_search_history_search_type ON search_history(search_type);

-- Rating history indexes
CREATE INDEX idx_rating_history_user_id ON rating_history(user_id);
CREATE INDEX idx_rating_history_title_id ON rating_history(title_id);
CREATE INDEX idx_rating_history_timestamp ON rating_history(timestamp DESC);
CREATE INDEX idx_rating_history_rating ON rating_history(rating);

-- Bookmark indexes
CREATE INDEX idx_bookmark_user_id ON bookmark(user_id);
CREATE INDEX idx_bookmark_title_id ON bookmark(title_id);
CREATE INDEX idx_bookmark_person_id ON bookmark(person_id);
CREATE INDEX idx_bookmark_type ON bookmark(bookmark_type);
CREATE INDEX idx_bookmark_created_at ON bookmark(created_at DESC);

-- ============================================
-- STEP 4: CREATE HELPER FUNCTIONS FOR FRAMEWORK
-- ============================================

-- Function to create a new user
CREATE OR REPLACE FUNCTION create_user(
    p_username VARCHAR(100),
    p_password VARCHAR(255),
    p_email VARCHAR(255) DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    new_user_id INTEGER;
BEGIN
    INSERT INTO "user" (username, password, email)
    VALUES (p_username, p_password, p_email)
    RETURNING id INTO new_user_id;
    
    RETURN new_user_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Username or email already exists';
END;
$$ LANGUAGE plpgsql;

-- Function to add a bookmark
CREATE OR REPLACE FUNCTION add_bookmark(
    p_user_id INTEGER,
    p_item_id VARCHAR(10),
    p_item_type VARCHAR(20),
    p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_item_type = 'title' THEN
        INSERT INTO bookmark (user_id, title_id, bookmark_type, notes)
        VALUES (p_user_id, p_item_id, 'title', p_notes)
        ON CONFLICT (user_id, title_id) DO UPDATE SET notes = EXCLUDED.notes;
    ELSIF p_item_type = 'person' THEN
        INSERT INTO bookmark (user_id, person_id, bookmark_type, notes)
        VALUES (p_user_id, p_item_id, 'person', p_notes)
        ON CONFLICT (user_id, person_id) DO UPDATE SET notes = EXCLUDED.notes;
    ELSE
        RAISE EXCEPTION 'Invalid bookmark type. Must be "title" or "person"';
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to remove a bookmark
CREATE OR REPLACE FUNCTION remove_bookmark(
    p_user_id INTEGER,
    p_item_id VARCHAR(10),
    p_item_type VARCHAR(20)
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_item_type = 'title' THEN
        DELETE FROM bookmark 
        WHERE user_id = p_user_id AND title_id = p_item_id;
    ELSIF p_item_type = 'person' THEN
        DELETE FROM bookmark 
        WHERE user_id = p_user_id AND person_id = p_item_id;
    ELSE
        RAISE EXCEPTION 'Invalid bookmark type. Must be "title" or "person"';
    END IF;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to get user bookmarks
CREATE OR REPLACE FUNCTION get_user_bookmarks(
    p_user_id INTEGER,
    p_bookmark_type VARCHAR(20) DEFAULT NULL
)
RETURNS TABLE (
    bookmark_id INTEGER,
    item_id VARCHAR(10),
    item_type VARCHAR(20),
    item_name TEXT,
    notes TEXT,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id,
        COALESCE(b.title_id, b.person_id),
        b.bookmark_type,
        CASE 
            WHEN b.bookmark_type = 'title' THEN t.primary_title
            WHEN b.bookmark_type = 'person' THEN p.primary_name
        END,
        b.notes,
        b.created_at
    FROM bookmark b
    LEFT JOIN title t ON b.title_id = t.id
    LEFT JOIN person p ON b.person_id = p.id
    WHERE b.user_id = p_user_id
        AND (p_bookmark_type IS NULL OR b.bookmark_type = p_bookmark_type)
    ORDER BY b.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get user's search history
CREATE OR REPLACE FUNCTION get_search_history(
    p_user_id INTEGER,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    search_id INTEGER,
    query TEXT,
    search_type VARCHAR(50),
    result_count INTEGER,
    timestamp TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        id,
        search_query,
        search_history.search_type,
        search_history.result_count,
        search_history.timestamp
    FROM search_history
    WHERE user_id = p_user_id
    ORDER BY timestamp DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to get user's rating history
CREATE OR REPLACE FUNCTION get_rating_history(
    p_user_id INTEGER,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    rating_id INTEGER,
    title_id VARCHAR(10),
    title_name TEXT,
    rating INTEGER,
    timestamp TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rh.id,
        rh.title_id,
        t.primary_title,
        rh.rating,
        rh.timestamp
    FROM rating_history rh
    JOIN title t ON rh.title_id = t.id
    WHERE rh.user_id = p_user_id
    ORDER BY rh.timestamp DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- STEP 5: CREATE VIEWS FOR COMMON QUERIES
-- ============================================

-- View for popular bookmarked titles
CREATE OR REPLACE VIEW popular_bookmarked_titles AS
SELECT 
    t.id,
    t.primary_title,
    COUNT(DISTINCT b.user_id) as bookmark_count
FROM bookmark b
JOIN title t ON b.title_id = t.id
WHERE b.bookmark_type = 'title'
GROUP BY t.id, t.primary_title
ORDER BY bookmark_count DESC;

-- View for popular bookmarked persons
CREATE OR REPLACE VIEW popular_bookmarked_persons AS
SELECT 
    p.id,
    p.primary_name,
    COUNT(DISTINCT b.user_id) as bookmark_count
FROM bookmark b
JOIN person p ON b.person_id = p.id
WHERE b.bookmark_type = 'person'
GROUP BY p.id, p.primary_name
ORDER BY bookmark_count DESC;

-- View for most searched queries
CREATE OR REPLACE VIEW popular_searches AS
SELECT 
    search_query,
    COUNT(*) as search_count,
    COUNT(DISTINCT user_id) as unique_users
FROM search_history
GROUP BY search_query
ORDER BY search_count DESC;

-- ============================================
-- STEP 6: INSERT TEST DATA (Optional - comment out in production)
-- ============================================

-- Create a test user
-- INSERT INTO "user" (username, password, email) 
-- VALUES ('testuser', 'hashed_password_here', 'test@example.com');

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Verify table creation
SELECT 'Framework tables created successfully' AS status;

-- List all framework tables
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('user', 'search_history', 'rating_history', 'bookmark')
ORDER BY table_name;