-- ==========================================
-- SEED DATA FOR TESTING FUNCTIONS
-- ==========================================

-- Wipe tables in the right order (child → parent)
TRUNCATE profile.rating_history,
         profile.search_history,
         profile.bookmark,
         profile.account,
         movie_db.actor,
         movie_db.crew,
         movie_db.genre,
         movie_db.rating,
         movie_db.episode,
         movie_db.title,
         movie_db.person
CASCADE;

-- ==========================================
-- Titles
-- ==========================================
INSERT INTO movie_db.title (id, title_type, primary_title, original_title, is_adult, start_year, runtime_minutes, plot)
VALUES 
('tt0001', 'movie', 'The Matrix', 'Matrix', FALSE, 1999, 136, 'A hacker discovers reality is a simulation.'),
('tt0002', 'movie', 'The Lord of the Rings', 'LOTR', FALSE, 2001, 178, 'A hobbit must destroy a powerful ring.'),
('tt0003', 'movie', 'Shrek', 'Shrek', FALSE, 2001, 90, 'An ogre rescues a princess with the help of a donkey.');

-- ==========================================
-- Ratings
-- ==========================================
INSERT INTO movie_db.rating (title_id, average_rating, num_votes)
VALUES
('tt0001', 8.7, 1000),
('tt0002', 8.8, 1500),
('tt0003', 7.9, 800);

-- ==========================================
-- Persons
-- ==========================================
INSERT INTO movie_db.person (id, primary_name, birth_year)
VALUES
('nm0001', 'Keanu Reeves', 1964),
('nm0002', 'Carrie-Anne Moss', 1967),
('nm0003', 'Elijah Wood', 1981),
('nm0004', 'Ian McKellen', 1939),
('nm0005', 'Mike Myers', 1963),
('nm0006', 'Eddie Murphy', 1961);

-- ==========================================
-- Actors
-- ==========================================
INSERT INTO movie_db.actor (title_id, person_id, character_name, credit_order)
VALUES
('tt0001', 'nm0001', 'Neo', 1),
('tt0001', 'nm0002', 'Trinity', 2),
('tt0002', 'nm0003', 'Frodo Baggins', 1),
('tt0002', 'nm0004', 'Gandalf', 2),
('tt0003', 'nm0005', 'Shrek', 1),
('tt0003', 'nm0006', 'Donkey', 2);

-- ==========================================
-- Crew
-- ==========================================
INSERT INTO movie_db.crew (title_id, person_id, category, job, credit_order)
VALUES
('tt0001', 'nm0001', 'actor', 'Lead actor', 1),
('tt0001', 'nm0002', 'actor', 'Lead actress', 2),
('tt0002', 'nm0003', 'actor', 'Lead actor', 1),
('tt0002', 'nm0004', 'actor', 'Supporting actor', 2),
('tt0003', 'nm0005', 'actor', 'Lead actor', 1),
('tt0003', 'nm0006', 'actor', 'Supporting actor', 2);

-- ==========================================
-- Genres
-- ==========================================
INSERT INTO movie_db.genre (title_id, genre) VALUES
('tt0001', 'Sci-Fi'),
('tt0001', 'Action'),
('tt0002', 'Fantasy'),
('tt0002', 'Adventure'),
('tt0003', 'Comedy'),
('tt0003', 'Animation');

-- ==========================================
-- User accounts
-- ==========================================
INSERT INTO profile.account (id, email, username, password_hash)
VALUES
(gen_random_uuid(), 'alice@example.com', 'alice', 'hashed_pw1'),
(gen_random_uuid(), 'bob@example.com', 'bob', 'hashed_pw2');

-- ==========================================
-- Bookmarks
-- ==========================================
INSERT INTO profile.bookmark (profile_id, title_id, note)
SELECT id, 'tt0001', 'Love this movie!' FROM profile.account WHERE username='alice';

INSERT INTO profile.bookmark (profile_id, title_id, note)
SELECT id, 'tt0002', 'Epic fantasy.' FROM profile.account WHERE username='bob';

-- ==========================================
-- Search history
-- ==========================================
INSERT INTO profile.search_history (profile_id, search_query)
SELECT id, 'matrix' FROM profile.account WHERE username='alice';

INSERT INTO profile.search_history (profile_id, search_query)
SELECT id, 'hobbit' FROM profile.account WHERE username='bob';

-- ==========================================
-- Rating history
-- ==========================================
INSERT INTO profile.rating_history (profile_id, title_id, rating, comment)
SELECT id, 'tt0001', 9, 'Mind-blowing' FROM profile.account WHERE username='alice';

INSERT INTO profile.rating_history (profile_id, title_id, rating, comment)
SELECT id, 'tt0003', 8, 'Funny and heartwarming' FROM profile.account WHERE username='bob';
