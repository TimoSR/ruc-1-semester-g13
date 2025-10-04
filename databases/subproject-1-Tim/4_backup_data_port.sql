-- ============================================
-- MIGRATE DATA FROM SOURCE TABLES
-- ============================================

-- Word Index (WI)

INSERT INTO movie_db.word_index (title_id, legacy_id, word, field, lexeme)
SELECT 
    t.id AS title_id,
    t.legacy_id,
    wi.word,
    wi.field,
    wi.lexeme
FROM public.wi wi
JOIN movie_db.title t
  ON t.legacy_id = trim(wi.tconst);  -- trim CHAR(10) padding

SELECT COUNT(*) FROM movie_db.word_index;

-- Titles
INSERT INTO movie_db.title (legacy_id, title_type, primary_title, original_title, is_adult, 
                  start_year, end_year, runtime_minutes, poster_url, plot)
SELECT 
    tb.tconst,
    tb.titletype,
    tb.primarytitle,
    tb.originaltitle,
    tb.isadult,
    NULLIF(NULLIF(tb.startyear, '\N'), '')::INT,
    NULLIF(NULLIF(tb.endyear, '\N'), '')::INT,
    tb.runtimeminutes,
    od.poster,
    od.plot
FROM public.title_basics tb
LEFT JOIN public.omdb_data od ON tb.tconst = od.tconst;

SELECT COUNT(*) FROM movie_db.title;

-- Episodes
INSERT INTO movie_db.episode (title_id, parent_id, season_number, episode_number)
SELECT 
    t.id,
    p.id,
    te.seasonnumber,
    te.episodenumber
FROM public.title_episode te
JOIN movie_db.title t ON t.legacy_id = te.tconst
LEFT JOIN movie_db.title p ON p.legacy_id = te.parenttconst;

-- Genres
DO $$
DECLARE
    rec RECORD;
    genre_item TEXT;
BEGIN
    FOR rec IN SELECT t.id, tb.genres
               FROM public.title_basics tb
               JOIN movie_db.title t ON t.legacy_id = tb.tconst
               WHERE tb.genres IS NOT NULL
    LOOP
        FOREACH genre_item IN ARRAY string_to_array(rec.genres, ',')
        LOOP
            INSERT INTO movie_db.genre (title_id, genre)
            VALUES (rec.id, TRIM(genre_item))
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- Alternate titles
INSERT INTO movie_db.also_known_as (title_id, list_order, title, region, language, 
                          types, attributes, is_original_title)
SELECT 
    t.id,
    ta.ordering,
    ta.title,
    ta.region,
    ta.language,
    ta.types,
    ta.attributes,
    ta.isoriginaltitle
FROM public.title_akas ta
JOIN movie_db.title t ON t.legacy_id = ta.titleid;

-- Ratings
INSERT INTO movie_db.rating (title_id, average_rating, num_votes)
SELECT 
    t.id,
    tr.averagerating,
    tr.numvotes
FROM public.title_ratings tr
JOIN movie_db.title t ON t.legacy_id = tr.tconst;

-- Persons
INSERT INTO movie_db.person (legacy_id, primary_name, birth_year, death_year)
SELECT 
    nb.nconst,
    nb.primaryname,
    NULLIF(NULLIF(nb.birthyear, '\N'), '')::INT,
    NULLIF(NULLIF(nb.deathyear, '\N'), '')::INT
FROM public.name_basics nb;

-- Known for
DO $$
DECLARE
    rec RECORD;
    title_item TEXT;
    title_uuid UUID;
BEGIN
    FOR rec IN SELECT p.id AS person_id, nb.knownfortitles
               FROM public.name_basics nb
               JOIN movie_db.person p ON p.legacy_id = nb.nconst
               WHERE nb.knownfortitles IS NOT NULL
    LOOP
        FOREACH title_item IN ARRAY string_to_array(rec.knownfortitles, ',')
        LOOP
            SELECT id INTO title_uuid FROM movie_db.title WHERE legacy_id = TRIM(title_item);
            IF title_uuid IS NOT NULL THEN
                INSERT INTO movie_db.person_known_for (person_id, title_id)
                VALUES (rec.person_id, title_uuid)
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- Professions
DO $$
DECLARE
    rec RECORD;
    profession_item TEXT;
BEGIN
    FOR rec IN SELECT p.id AS person_id, nb.primaryprofession
               FROM public.name_basics nb
               JOIN movie_db.person p ON p.legacy_id = nb.nconst
               WHERE nb.primaryprofession IS NOT NULL
    LOOP
        FOREACH profession_item IN ARRAY string_to_array(rec.primaryprofession, ',')
        LOOP
            INSERT INTO movie_db.person_profession (person_id, profession)
            VALUES (rec.person_id, TRIM(profession_item))
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;
END $$;

-- Crew
INSERT INTO movie_db.crew (title_id, person_id, category, job, credit_order)
SELECT 
    t.id,
    p.id,
    tp.category,
    tp.job,
    tp.ordering
FROM public.title_principals tp
JOIN movie_db.title t ON t.legacy_id = tp.tconst
JOIN movie_db.person p ON p.legacy_id = tp.nconst
WHERE tp.category NOT IN ('actor', 'actress', 'self')
ON CONFLICT DO NOTHING;

-- Actors
INSERT INTO movie_db.actor (title_id, person_id, character_name, credit_order)
SELECT 
    t.id,
    p.id,
    tp.characters,
    tp.ordering
FROM public.title_principals tp
JOIN movie_db.title t ON t.legacy_id = tp.tconst
JOIN movie_db.person p ON p.legacy_id = tp.nconst
WHERE tp.category IN ('actor', 'actress', 'self')
ON CONFLICT DO NOTHING;

-- ============================================
-- STEP 5: DROP SOURCE TABLES
-- ============================================
DROP TABLE IF EXISTS public.title_akas CASCADE;
DROP TABLE IF EXISTS public.title_basics CASCADE;
DROP TABLE IF EXISTS public.title_crew CASCADE;
DROP TABLE IF EXISTS public.title_episode CASCADE;
DROP TABLE IF EXISTS public.title_principals CASCADE;
DROP TABLE IF EXISTS public.title_ratings CASCADE;
DROP TABLE IF EXISTS public.name_basics CASCADE;
DROP TABLE IF EXISTS public.omdb_data CASCADE;
DROP TABLE IF EXISTS public.wi CASCADE;