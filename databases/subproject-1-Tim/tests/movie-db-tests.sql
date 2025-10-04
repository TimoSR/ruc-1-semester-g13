-- ============================================
-- B2_function_tests.sql (UUIDs with explicit casts)
-- ============================================

-- ============================================
-- Seed test data
-- ============================================

-- Titles
INSERT INTO movie_db.title (id, legacy_id, title_type, primary_title, plot)
VALUES 
  ('11111111-1111-1111-1111-111111111111'::uuid, 'seed1', 'movie', 'Test Movie A', 'A hero saves the world'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'seed2', 'movie', 'Test Movie B', 'A villain takes over'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'seed3', 'movie', 'Romantic Movie', 'A love story plot');

-- Genres
INSERT INTO movie_db.genre (id, title_id, genre) VALUES
  ('aaaa1111-0000-0000-0000-000000000001'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, 'Action'),
  ('aaaa1111-0000-0000-0000-000000000002'::uuid, '22222222-2222-2222-2222-222222222222'::uuid, 'Action'),
  ('aaaa1111-0000-0000-0000-000000000003'::uuid, '33333333-3333-3333-3333-333333333333'::uuid, 'Romance');

-- Persons
INSERT INTO movie_db.person (id, legacy_id, primary_name) VALUES
  ('44444444-4444-4444-4444-444444444444'::uuid, 'pseed1', 'Actor A'),
  ('55555555-5555-5555-5555-555555555555'::uuid, 'pseed2', 'Actor B'),
  ('66666666-6666-6666-6666-666666666666'::uuid, 'pseed3', 'Actor C');

-- Actors (roles)
INSERT INTO movie_db.actor (id, title_id, person_id, character_name) VALUES
  ('aaaa2222-0000-0000-0000-000000000001'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, '44444444-4444-4444-4444-444444444444'::uuid, 'Hero'),
  ('aaaa2222-0000-0000-0000-000000000002'::uuid, '11111111-1111-1111-1111-111111111111'::uuid, '55555555-5555-5555-5555-555555555555'::uuid, 'Sidekick'),
  ('aaaa2222-0000-0000-0000-000000000003'::uuid, '22222222-2222-2222-2222-222222222222'::uuid, '55555555-5555-5555-5555-555555555555'::uuid, 'Villain'),
  ('aaaa2222-0000-0000-0000-000000000004'::uuid, '22222222-2222-2222-2222-222222222222'::uuid, '66666666-6666-6666-6666-666666666666'::uuid, 'Victim');

-- Word index
INSERT INTO movie_db.word_index (id, legacy_id, title_id, word, field) VALUES
  ('aaaa3333-0000-0000-0000-000000000001'::uuid, 'w1', '11111111-1111-1111-1111-111111111111'::uuid, 'hero', 'p'),
  ('aaaa3333-0000-0000-0000-000000000002'::uuid, 'w2', '22222222-2222-2222-2222-222222222222'::uuid, 'villain', 'p');

-- ============================================
-- Function Tests
-- ============================================

-- First rating
SELECT *
FROM api.add_user_title_rating(
  '77777777-7777-7777-7777-777777777777'::uuid,  -- account 1
  '11111111-1111-1111-1111-111111111111'::uuid,  -- title
  8                                              -- rating
);

-- Second rating
SELECT *
FROM api.add_user_title_rating(
  '88888888-8888-8888-8888-888888888888'::uuid,  -- account 2
  '11111111-1111-1111-1111-111111111111'::uuid,  -- same title
  6                                              -- rating
);

-- ✅ Expect: average_rating ≈ 7.0, num_votes = 2
SELECT *
FROM movie_db.rating
WHERE title_id = '11111111-1111-1111-1111-111111111111'::uuid;

-- Expect: average_rating ≈ 7.0, num_votes = 2
TABLE movie_db.rating;

-- 2. get_person_by_name
SELECT '--- api.get_person_by_name ---';
SELECT * FROM api.get_person_by_name('Actor A');

-- 3. get_coplayers
SELECT '--- api.get_coplayers ---';
SELECT * FROM api.get_coplayers('Actor B');
-- Expect: Actor A and Actor C as co-players

-- 4. get_popular_co_actors
SELECT '--- api.get_popular_co_actors ---';
REFRESH MATERIALIZED VIEW movie_db.get_actor_avg_title_rating;
SELECT * FROM api.get_popular_co_actors('Actor B');

-- 5. get_similar_movies
SELECT '--- api.get_similar_movies ---';
SELECT * FROM api.get_similar_movies('11111111-1111-1111-1111-111111111111'::uuid, 10);

-- 6. string_search_title
SELECT '--- api.string_search_title ---';
SELECT * FROM api.string_search_title('hero');

-- 7. structured_string_search
SELECT '--- api.structured_string_search ---';
SELECT * FROM api.structured_string_search('Romantic', NULL, NULL, NULL);

-- 8. person_words
SELECT '--- api.person_words ---';
SELECT * FROM api.person_words('Actor A', 5);

-- 9. exact_match_query
SELECT '--- api.exact_match_query ---';
SELECT * FROM api.exact_match_query(ARRAY['hero']);

-- 10. best_match_query
SELECT '--- api.best_match_query ---';
SELECT * FROM api.best_match_query(ARRAY['hero','villain']);

-- 11. word_to_words_query
SELECT '--- api.word_to_words_query ---';
SELECT * FROM api.word_to_words_query(ARRAY['hero'], 10);

-- ============================================
-- End of tests
-- ============================================
