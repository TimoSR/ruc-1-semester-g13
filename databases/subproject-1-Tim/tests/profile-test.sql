-- ============================================
-- Testing API schema
-- ============================================

-- Seed Alice
-- Use a known UUID for Alice (so your tests can always reference it)
INSERT INTO profile.account (id, email, username, password_hash)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'alice@example.com',
  'alice',
  'hashed_pw'
)
ON CONFLICT (username) DO NOTHING;

-- Now test using :alice_id
SELECT api.add_bookmark('11111111-1111-1111-1111-111111111111', 'tt0001', 'Loved this movie');
SELECT * FROM api.get_bookmarks('11111111-1111-1111-1111-111111111111');

SELECT api.add_search_to_history('11111111-1111-1111-1111-111111111111', 'matrix');
SELECT * FROM api.search_history('11111111-1111-1111-1111-111111111111', 5);

SELECT api.add_rating('11111111-1111-1111-1111-111111111111', 'tt0001', 9, 'Mind-blowing');
SELECT * FROM api.get_ratings('11111111-1111-1111-1111-111111111111');

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
