CREATE SCHEMA api;
CREATE SCHEMA profile;

-- ============================================
-- TABLES
-- ============================================

CREATE TABLE profile.account (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL
);

CREATE TABLE profile.bookmark (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profile.account(id) ON DELETE CASCADE,
    title_id VARCHAR(20) NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    note TEXT,
    added_at TIMESTAMP DEFAULT now(),
    UNIQUE (profile_id, title_id)
);

CREATE TABLE profile.search_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profile.account(id) ON DELETE CASCADE,
    search_query TEXT NOT NULL,
    searched_at TIMESTAMP DEFAULT now()
);

CREATE TABLE profile.rating_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES profile.account(id) ON DELETE CASCADE,
    title_id VARCHAR(20) NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    rating INT CHECK (rating BETWEEN 1 AND 10),
    comment TEXT,
    created_at TIMESTAMP DEFAULT now(),
    UNIQUE (profile_id, title_id)
);

-- ============================================
-- FUNCTIONS (API schema)
-- ============================================

CREATE OR REPLACE FUNCTION api.create_account(
    email TEXT,
    username TEXT,
    password_hash TEXT
) RETURNS UUID AS $$
DECLARE
    new_id UUID;
BEGIN
    INSERT INTO profile.account (email, username, password_hash)
    VALUES (email, username, password_hash)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.delete_account(
    account_id UUID
) RETURNS VOID AS $$
BEGIN
    DELETE FROM profile.account WHERE id = account_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.add_bookmark(
    profile_id UUID,
    title_id VARCHAR(20),
    note TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO profile.bookmark (profile_id, title_id, note)
    VALUES (profile_id, title_id, note)
    ON CONFLICT (profile_id, title_id)
    DO UPDATE SET note = EXCLUDED.note, added_at = now();
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.get_bookmarks(
    profile_id UUID
) RETURNS TABLE(
    title_id VARCHAR(20),
    note TEXT,
    added_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT profile.bookmark.title_id,
           profile.bookmark.note,
           profile.bookmark.added_at
    FROM profile.bookmark
    WHERE profile.bookmark.profile_id = profile_id
    ORDER BY profile.bookmark.added_at DESC;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.search_history(
    profile_id UUID,
    query TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO profile.search_history (profile_id, search_query)
    VALUES (profile_id, query);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.search_history(
    profile_id UUID,
    limit_rows INT DEFAULT 10
) RETURNS TABLE(
    query TEXT,
    searched_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT profile.search_history.search_query,
           profile.search_history.searched_at
    FROM profile.search_history
    WHERE profile.search_history.profile_id = profile_id
    ORDER BY profile.search_history.searched_at DESC
    LIMIT limit_rows;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.add_rating(
    profile_id UUID,
    title_id VARCHAR(20),
    rating INT,
    comment TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO profile.rating_history (profile_id, title_id, rating, comment)
    VALUES (profile_id, title_id, rating, comment)
    ON CONFLICT (profile_id, title_id)
    DO UPDATE SET rating = EXCLUDED.rating,
                  comment = EXCLUDED.comment,
                  created_at = now();
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.get_ratings(
    profile_id UUID
) RETURNS TABLE(
    title_id VARCHAR(20),
    rating INT,
    comment TEXT,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT profile.rating_history.title_id,
           profile.rating_history.rating,
           profile.rating_history.comment,
           profile.rating_history.created_at
    FROM profile.rating_history
    WHERE profile.rating_history.profile_id = profile_id
    ORDER BY profile.rating_history.created_at DESC;
END;
$$ LANGUAGE plpgsql;