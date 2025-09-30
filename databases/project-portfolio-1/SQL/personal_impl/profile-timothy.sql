CREATE SCHEMA api;
CREATE SCHEMA profile;

-- ============================================
-- TABLES
-- ============================================

CREATE TABLE profile.account (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT now();
);

CREATE TABLE profile.bookmark (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES profile.account(id) ON DELETE CASCADE,
    title_id VARCHAR(20) NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    note TEXT,
    added_at TIMESTAMP DEFAULT now(),
    UNIQUE (account_id, title_id)
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
    title_id VARCHAR(20) NOT NULL REFERENCES movie_db.title(id) ON DELETE CASCADE,
    rating INT CHECK (rating BETWEEN 1 AND 10),
    comment TEXT,
    created_at TIMESTAMP DEFAULT now(),
    UNIQUE (account_id, title_id)
);

-- ============================================
-- FUNCTIONS (API schema)
-- ============================================

CREATE OR REPLACE PROCEDURE api.create_account(
    email TEXT,
    username TEXT,
    password_hash TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_id UUID;
BEGIN
    INSERT INTO profile.account (email, username, password_hash)
    VALUES (email, username, password_hash)
    RETURNING id INTO new_id;
    COMMIT;

    RAISE NOTICE 'Created account with id %', new_id;

EXCEPTION WHEN OTHERS THEN
    ROLLBACK;
    RAISE EXCEPTION 'Failed to create account: %', SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE api.delete_account(
    account_id UUID
)
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM profile.account WHERE id = account_id;

    IF NOT FOUND THEN
        ROLLBACK;
        RAISE EXCEPTION 'Account % does not exist', account_id;
    END IF;

    COMMIT;

    RAISE NOTICE 'Deleted account %', account_id;

EXCEPTION WHEN OTHERS THEN
    ROLLBACK;
    RAISE EXCEPTION 'Failed to delete account %: %', account_id, SQLERRM;
END;
$$;

CREATE OR REPLACE FUNCTION api.get_accounts()
RETURNS TABLE(
    id UUID,
    email TEXT,
    username TEXT,
    created_at TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT profile.account.id,
           profile.account.email,
           profile.account.username,
           profile.account_id::text::timestamp AS created_at
    FROM profile.account
    ORDER BY profile.account.username;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION api.add_bookmark(
    account_id UUID,
    title_id VARCHAR(20),
    note TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO profile.bookmark (account_id, title_id, note)
    VALUES (account_id, title_id, note)
    ON CONFLICT (account_id, title_id)
    DO UPDATE SET note = EXCLUDED.note, added_at = now();
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.get_bookmarks(
    account_id UUID
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
    WHERE profile.bookmark.account_id = account_id
    ORDER BY profile.bookmark.added_at DESC;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.add_search_to_history(
    account_id UUID,
    query TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO profile.search_history (account_id, search_query)
    VALUES (account_id, query);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.search_history(
    account_id UUID,
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
    WHERE profile.search_history.account_id = account_id
    ORDER BY profile.search_history.searched_at DESC
    LIMIT limit_rows;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.add_rating(
    account_id UUID,
    title_id VARCHAR(20),
    rating INT,
    comment TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO profile.rating_history (account_id, title_id, rating, comment)
    VALUES (account_id, title_id, rating, comment)
    ON CONFLICT (account_id, title_id)
    DO UPDATE SET rating = EXCLUDED.rating,
                  comment = EXCLUDED.comment,
                  created_at = now();
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION api.get_ratings(
    account_id UUID
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
    WHERE profile.rating_history.account_id = account_id
    ORDER BY profile.rating_history.created_at DESC;
END;
$$ LANGUAGE plpgsql;