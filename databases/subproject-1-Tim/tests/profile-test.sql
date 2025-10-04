-- ============================================
-- SEED DATA
-- ============================================

-- Known UUIDs for consistent tests
INSERT INTO profile.account (id, email, username, password_hash)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com', 'alice', 'pw_alice'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com',   'bob',   'pw_bob')
ON CONFLICT (username) DO NOTHING;

-- ============================================
-- TEST ACCOUNT PROCEDURES
-- ============================================

-- Should create a new account "charlie"
CALL api.create_account('charlie@example.com', 'charlie', 'pw_charlie');

-- Attempt to delete an existing account
CALL api.delete_account('22222222-2222-2222-2222-222222222222');

-- Attempt to delete a non-existing account (should raise exception)
DO $$
BEGIN
    BEGIN
        CALL api.delete_account('99999999-9999-9999-9999-999999999999');
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected error deleting non-existent account: %', SQLERRM;
    END;
END;
$$;

-- ============================================
-- TEST ACCOUNTS VIEW & PAGINATION
-- ============================================

-- All accounts
SELECT * FROM api.get_all_accounts;

-- First 2 accounts
SELECT * FROM api.get_accounts(2, 0);

-- Next page
SELECT * FROM api.get_accounts(2, 2);

-- ============================================================
-- TESTING BOOKMARKS (Titles + Persons)
-- ============================================================

-- Add a title bookmark for Alice
SELECT api.add_bookmark(
  '11111111-1111-1111-1111-111111111111'::uuid, -- account_id
  '11111111-2222-3333-4444-555555555555'::uuid, -- title_id
  'title'::bookmark_target
);

-- Add another title bookmark
SELECT api.add_bookmark(
  '11111111-1111-1111-1111-111111111111'::uuid,
  '66666666-7777-8888-9999-000000000000'::uuid,
  'title'::bookmark_target
);

-- Try adding the same bookmark again (should raise NOTICE, not duplicate)
SELECT api.add_bookmark(
  '11111111-1111-1111-1111-111111111111'::uuid,
  '11111111-2222-3333-4444-555555555555'::uuid,
  'title'::bookmark_target
);

-- Add a person bookmark
SELECT api.add_bookmark(
  '11111111-1111-1111-1111-111111111111'::uuid,
  'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'::uuid,
  'person'::bookmark_target
);

-- Update the note on the first title bookmark
SELECT api.update_bookmark_note(
  '11111111-1111-1111-1111-111111111111'::uuid,
  '11111111-2222-3333-4444-555555555555'::uuid,
  'title'::bookmark_target,
  '{"text": "Changed my mind"}'
);

-- Update the note on the person bookmark
SELECT api.update_bookmark_note(
  '11111111-1111-1111-1111-111111111111'::uuid,
  'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'::uuid,
  'person'::bookmark_target,
  '{"text": "Favourite actor"}'
);

-- Remove note from title bookmark (set back to NULL)
SELECT api.update_bookmark_note(
  '11111111-1111-1111-1111-111111111111'::uuid,
  '11111111-2222-3333-4444-555555555555'::uuid,
  'title'::bookmark_target,
  NULL
);

-- Try updating a non-existing bookmark (should raise EXCEPTION)
DO $$
BEGIN
    BEGIN
        PERFORM api.update_bookmark_note(
          '11111111-1111-1111-1111-111111111111'::uuid,
          '99999999-aaaa-bbbb-cccc-111111111111'::uuid,
          'title'::bookmark_target,
          '{"text": "This should fail"}'
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Expected error updating non-existent bookmark: %', SQLERRM;
    END;
END;
$$;

-- Get all bookmarks for Alice
SELECT * FROM api.get_bookmarks('11111111-1111-1111-1111-111111111111'::uuid);

-- Get only title bookmarks
SELECT * FROM api.get_bookmarks('11111111-1111-1111-1111-111111111111'::uuid, 'title'::bookmark_target);

-- Get only person bookmarks
SELECT * FROM api.get_bookmarks('11111111-1111-1111-1111-111111111111'::uuid, 'person'::bookmark_target);

-- ============================================
-- TEST SEARCH HISTORY
-- ============================================

-- Add searches
SELECT api.add_search_to_history('11111111-1111-1111-1111-111111111111'::uuid, 'matrix');
SELECT api.add_search_to_history('11111111-1111-1111-1111-111111111111'::uuid, 'harry potter');
-- Get Alice’s searches (limit 5)
SELECT * FROM api.get_search_history('11111111-1111-1111-1111-111111111111'::uuid, 5, 0);

-- ============================================
-- TEST RATINGS
-- ============================================

-- Add rating for Alice
SELECT api.add_rating(
  '11111111-1111-1111-1111-111111111111'::uuid,
  '22222222-3333-4444-5555-666666666666'::uuid, -- UUID for a title
  8,
  'Pretty good'
);

-- Update same rating
SELECT api.add_rating(
  '11111111-1111-1111-1111-111111111111'::uuid,
  '22222222-3333-4444-5555-666666666666'::uuid,
  9,
  'Even better'
);

-- Add another rating
SELECT api.add_rating(
  '11111111-1111-1111-1111-111111111111'::uuid,
  '77777777-8888-9999-0000-aaaaaaaaaaaa'::uuid, -- another title UUID
  5,
  'Meh'
);

-- Get Alice’s ratings
SELECT * FROM api.get_ratings_by_account_id(
  '11111111-1111-1111-1111-111111111111'::uuid,
  10,
  0
);


-- ============================================
-- TEST MATERIALIZED VIEW
-- ============================================

-- Refresh to ensure up-to-date averages
REFRESH MATERIALIZED VIEW api.title_avg_ratings;

-- Check aggregated ratings
SELECT * FROM api.title_avg_ratings ORDER BY avg_rating DESC;