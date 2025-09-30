-- ============================================
-- Testing API schema
-- ============================================


SELECT api.create_account('alice@example.com', 'alice', 'hashed_pw');
SELECT api.add_bookmark('uuid-of-alice', 'tt0001', 'Loved this movie');
SELECT * FROM api.get_bookmarks('uuid-of-alice');
SELECT api.search_history('uuid-of-alice', 'matrix');
SELECT * FROM api.search_history('uuid-of-alice', 5);
SELECT api.add_rating('uuid-of-alice', 'tt0001', 9, 'Mind-blowing');
SELECT * FROM api.get_ratings('uuid-of-alice');