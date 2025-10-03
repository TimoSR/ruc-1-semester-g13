-- ============================================
-- STEP 1: DROP EXISTING OBJECTS (for repeatability)
-- ============================================

-- Drop views & functions in api schema
DROP VIEW IF EXISTS api.accounts CASCADE;
DROP FUNCTION IF EXISTS api.get_accounts() CASCADE;
DROP FUNCTION IF EXISTS api.add_bookmark(UUID, VARCHAR, TEXT) CASCADE;
DROP FUNCTION IF EXISTS api.get_bookmarks(UUID) CASCADE;
DROP FUNCTION IF EXISTS api.add_search_to_history(UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS api.search_history(UUID, INT) CASCADE;
DROP FUNCTION IF EXISTS api.add_rating(UUID, VARCHAR, INT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS api.get_ratings(UUID) CASCADE;
DROP PROCEDURE IF EXISTS api.create_account(TEXT, TEXT, TEXT) CASCADE;
DROP PROCEDURE IF EXISTS api.delete_account(UUID) CASCADE;

-- Drop profile tables
DROP TABLE IF EXISTS profile.rating_history CASCADE;
DROP TABLE IF EXISTS profile.search_history CASCADE;
DROP TABLE IF EXISTS profile.bookmark CASCADE;
DROP TABLE IF EXISTS profile.account CASCADE;

-- ============================================
-- TABLES
-- ============================================

CREATE TABLE profile.account (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE profile.bookmark_title (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES profile.account(id) ON DELETE CASCADE,
    title_id UUID NOT NULL,
    note TEXT,
    added_at TIMESTAMP DEFAULT now(),
    UNIQUE (account_id, title_id)
);

CREATE TABLE profile.bookmark_person (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES profile.account(id) ON DELETE CASCADE,
    person_id UUID NOT NULL,
    note TEXT,
    added_at TIMESTAMP DEFAULT now(),
    UNIQUE (account_id, person_id)
);

CREATE TABLE profile.search_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES profile.account(id) ON DELETE CASCADE,
    search_query TEXT NOT NULL,
    searched_at TIMESTAMP DEFAULT now()
);

CREATE TABLE profile.rating_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES profile.account(id) ON DELETE CASCADE,
    title_id UUID NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 10),
    comment TEXT,
    created_at TIMESTAMP DEFAULT now(),
    UNIQUE (account_id, title_id)
);

-- ============================================
-- FUNCTIONS (API schema)
-- ============================================

-- =========================================================
-- ACCOUNT PROCEDURES
-- =========================================================

CREATE OR REPLACE PROCEDURE api.create_account(
	p_email TEXT,
	p_username TEXT,
	p_password_hash TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
	new_id UUID;
BEGIN
	INSERT INTO profile.account (email, username, password_hash)
	VALUES (p_email, p_username, p_password_hash)
	RETURNING id INTO new_id;

	RAISE NOTICE 'Created account with id %', new_id;
END;
$$;

CREATE OR REPLACE PROCEDURE api.delete_account(
	p_account_id UUID
)
LANGUAGE plpgsql
AS $$
BEGIN
	DELETE FROM profile.account WHERE id = p_account_id;

	IF NOT FOUND THEN
		RAISE EXCEPTION 'Account % does not exist', p_account_id;
	END IF;

	RAISE NOTICE 'Deleted account %', p_account_id;
END;
$$;

CREATE OR REPLACE FUNCTION api.get_account_info(p_id UUID)
RETURNS TABLE(id UUID, email TEXT, username TEXT, created_at TIMESTAMP) 
AS $$
BEGIN
	RETURN QUERY
	SELECT a.id,
		   a.email,
		   a.username,
		   a.created_at
	FROM profile.account a
	WHERE a.id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW api.get_all_accounts AS
SELECT a.id,
	   a.email,
	   a.username,
	   a.created_at
FROM profile.account a;

CREATE OR REPLACE FUNCTION api.get_accounts(
	p_limit INT DEFAULT 50,
	p_offset INT DEFAULT 0
)
RETURNS TABLE(id UUID, email TEXT, username TEXT, created_at TIMESTAMP) 
AS $$
BEGIN
	RETURN QUERY
	SELECT a.id,
		   a.email,
		   a.username,
		   a.created_at
	FROM profile.account a
	ORDER BY a.created_at DESC
	LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- BOOKMARKS
-- =========================================================

CREATE OR REPLACE FUNCTION api.add_bookmark(
	p_account_id UUID,
	p_title_id VARCHAR(20),
	p_note TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
	INSERT INTO profile.bookmark (account_id, title_id, note)
	VALUES (p_account_id, p_title_id, p_note)
	ON CONFLICT (account_id, title_id)
	DO UPDATE SET note = EXCLUDED.note, added_at = now();
END;
$$ LANGUAGE plpgsql;

CREATE TYPE bookmark_target AS ENUM ('all', 'title', 'person');

CREATE OR REPLACE FUNCTION api.get_bookmarks(
    p_account_id UUID,
    e_type bookmark_target DEFAULT 'all',
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
) RETURNS TABLE(
    target_id UUID,
    target_type TEXT,
    note TEXT,
    added_at TIMESTAMP
) AS $$
BEGIN
    IF e_type = 'title' THEN
        RETURN QUERY
        SELECT b.title_id, 'title'::TEXT, b.note, b.added_at
        FROM profile.bookmark_title b
        WHERE b.account_id = p_account_id
        ORDER BY b.added_at DESC
        LIMIT p_limit OFFSET p_offset;

    ELSIF e_type = 'person' THEN
        RETURN QUERY
        SELECT b.person_id, 'person'::TEXT, b.note, b.added_at
        FROM profile.bookmark_person b
        WHERE b.account_id = p_account_id
        ORDER BY b.added_at DESC
        LIMIT p_limit OFFSET p_offset;

    ELSE -- e_type = 'all'
        RETURN QUERY
        SELECT b.title_id, 'title'::TEXT, b.note, b.added_at
        FROM profile.bookmark_title b
        WHERE b.account_id = p_account_id

        UNION ALL

        SELECT b.person_id, 'person'::TEXT, b.note, b.added_at
        FROM profile.bookmark_person b
        WHERE b.account_id = p_account_id

        ORDER BY added_at DESC
        LIMIT p_limit OFFSET p_offset;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- SEARCH HISTORY
-- =========================================================

CREATE OR REPLACE FUNCTION api.add_search_to_history(
	p_account_id UUID,
	p_query TEXT
) RETURNS VOID AS $$
BEGIN
	INSERT INTO profile.search_history (account_id, search_query)
	VALUES (p_account_id, p_query);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.get_search_history(
	p_account_id UUID,
	p_limit INT DEFAULT 50,
	p_offset INT DEFAULT 0
) RETURNS TABLE(
	query TEXT,
	searched_at TIMESTAMP
) AS $$
BEGIN
	RETURN QUERY
	SELECT sh.search_query,
		   sh.searched_at
	FROM profile.search_history sh
	WHERE sh.account_id = p_account_id
	ORDER BY sh.searched_at DESC
	LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;


-- =========================================================
-- RATINGS (already fixed before)
-- =========================================================

CREATE OR REPLACE FUNCTION api.add_rating(
	p_account_id UUID,
	p_title_id   VARCHAR(20),
	p_rating     INT,
	p_comment    TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
	INSERT INTO profile.rating_history (account_id, title_id, rating, comment)
	VALUES (p_account_id, p_title_id, p_rating, p_comment)
	ON CONFLICT (account_id, title_id)
	DO UPDATE SET 
		rating     = EXCLUDED.rating,
		comment    = EXCLUDED.comment,
		created_at = now();
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.get_ratings_by_account_id(
	p_account_id UUID,
	p_limit INT DEFAULT 50,
	p_offset INT DEFAULT 0
) RETURNS TABLE(
	title_id VARCHAR(20),
	rating INT,
	comment TEXT,
	created_at TIMESTAMP
) AS $$
BEGIN
	RETURN QUERY
	SELECT rh.title_id,
		   rh.rating,
		   rh.comment,
		   rh.created_at
	FROM profile.rating_history rh
	WHERE rh.account_id = p_account_id
	ORDER BY rh.created_at DESC
	LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

CREATE MATERIALIZED VIEW api.title_avg_ratings AS
SELECT title_id, AVG(rating) AS avg_rating, COUNT(*) AS num_ratings
FROM profile.rating_history
GROUP BY title_id;