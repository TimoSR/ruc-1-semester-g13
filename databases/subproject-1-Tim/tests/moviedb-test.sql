-- ============================================
-- VERIFICATION QUERIES
-- ============================================
SELECT 'Titles migrated:' AS info, COUNT(*) AS count FROM movie_db.title;
SELECT 'Episodes migrated:' AS info, COUNT(*) AS count FROM movie_db.episode;
SELECT 'Genres migrated:' AS info, COUNT(*) AS count FROM movie_db.genre;
SELECT 'Ratings migrated:' AS info, COUNT(*) AS count FROM movie_db.rating;
SELECT 'Persons migrated:' AS info, COUNT(*) AS count FROM movie_db.person;
SELECT 'Actors migrated:' AS info, COUNT(*) AS count FROM movie_db.actor;
SELECT 'Crew migrated:' AS info, COUNT(*) AS count FROM movie_db.crew;