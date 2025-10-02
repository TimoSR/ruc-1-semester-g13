-- ============================================
-- Testing API schema
-- ============================================

SELECT api.add_bookmark('uuid-of-alice', 'tt0001', 'Loved this movie');
SELECT * FROM api.get_bookmarks('uuid-of-alice');
SELECT api.add_search_to_history('uuid-of-alice', 'matrix');
SELECT * FROM api.search_history('uuid-of-alice', 5);
SELECT api.add_rating('uuid-of-alice', 'tt0001', 9, 'Mind-blowing');
SELECT * FROM api.get_ratings('uuid-of-alice');

--- These will not work within a transaction as they are already within a transaction managed by the db
CALL api.create_account('alice@example.com', 'alice', 'hashed_pw');

--- Get ID and the delete
DO $$
DECLARE
    account_id UUID;
BEGIN
    SELECT id INTO account_id
    FROM api.get_accounts()
    WHERE username = 'alice';
    LIMIT 1;
    CALL api.delete_account(account_id);
END;
$$;