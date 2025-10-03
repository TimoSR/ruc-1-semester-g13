-- ===========================
-- 1.1 Manage users
-- ===========================

-- Create (returns id)
CREATE OR REPLACE FUNCTION create_user(p_username TEXT, p_password TEXT)
RETURNS INT
LANGUAGE sql AS $$
  INSERT INTO profile(username, password)
  VALUES (p_username, p_password)
  ON CONFLICT (username) DO UPDATE SET username = EXCLUDED.username
  RETURNING id;
$$;

-- Find by username (returns id)
CREATE OR REPLACE FUNCTION find_user(p_username TEXT)
RETURNS INT
LANGUAGE sql AS $$
  SELECT id FROM profile WHERE username = p_username LIMIT 1;
$$;

-- Change password
CREATE OR REPLACE FUNCTION change_password(p_profile_id INT, p_new TEXT)
RETURNS VOID
LANGUAGE sql AS $$
  UPDATE profile SET password = p_new WHERE id = p_profile_id;
$$;

-- Delete user (CASCADE rydder relaterede rækker)
CREATE OR REPLACE FUNCTION delete_user(p_profile_id INT)
RETURNS VOID
LANGUAGE sql AS $$
  DELETE FROM profile WHERE id = p_profile_id;
$$;


-- ===========================
-- 1.2 Bookmarks (samlet 'bookmark' tabel)
-- ===========================

-- Title bookmarks
CREATE OR REPLACE FUNCTION add_bookmark_title(p_profile_id INT, p_title_id VARCHAR(20))
RETURNS VOID
LANGUAGE sql AS $$
  INSERT INTO bookmark(profile_id, title_id, person_id, bookmark_type)
  VALUES (p_profile_id, p_title_id, NULL, 'title')
  ON CONFLICT (profile_id, title_id) DO NOTHING;
$$;

CREATE OR REPLACE FUNCTION remove_bookmark_title(p_profile_id INT, p_title_id VARCHAR(20))
RETURNS VOID
LANGUAGE sql AS $$
  DELETE FROM bookmark
  WHERE profile_id = p_profile_id
    AND title_id   = p_title_id
    AND bookmark_type='title';
$$;

CREATE OR REPLACE FUNCTION list_bookmarked_titles(p_profile_id INT)
RETURNS TABLE (title_id VARCHAR(20), primary_title VARCHAR(500))
LANGUAGE sql AS $$
  SELECT b.title_id, t.primary_title
  FROM bookmark b
  JOIN title t ON t.id = b.title_id
  WHERE b.profile_id = p_profile_id
    AND b.bookmark_type='title'
  ORDER BY t.primary_title;
$$;

-- Person bookmarks
CREATE OR REPLACE FUNCTION add_bookmark_person(p_profile_id INT, p_person_id VARCHAR(20))
RETURNS VOID
LANGUAGE sql AS $$
  INSERT INTO bookmark(profile_id, title_id, person_id, bookmark_type)
  VALUES (p_profile_id, NULL, p_person_id, 'person')
  ON CONFLICT (profile_id, person_id) DO NOTHING;
$$;

CREATE OR REPLACE FUNCTION remove_bookmark_person(p_profile_id INT, p_person_id VARCHAR(20))
RETURNS VOID
LANGUAGE sql AS $$
  DELETE FROM bookmark
  WHERE profile_id = p_profile_id
    AND person_id  = p_person_id
    AND bookmark_type='person';
$$;

CREATE OR REPLACE FUNCTION list_bookmarked_persons(p_profile_id INT)
RETURNS TABLE (person_id VARCHAR(20), primary_name VARCHAR(100))
LANGUAGE sql AS $$
  SELECT b.person_id, p.primary_name
  FROM bookmark b
  JOIN person p ON p.id = b.person_id
  WHERE b.profile_id = p_profile_id
    AND b.bookmark_type='person'
  ORDER BY p.primary_name;
$$;


-- ===========================
-- 1.3 Notes (tilføjer små note-tabeller + CRUD)
-- ===========================

CREATE TABLE IF NOT EXISTS note_title(
  profile_id INT         REFERENCES profile(id) ON DELETE CASCADE,
  title_id   VARCHAR(20) REFERENCES title(id)   ON DELETE CASCADE,
  note       TEXT NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY(profile_id, title_id)
);

CREATE TABLE IF NOT EXISTS note_person(
  profile_id INT         REFERENCES profile(id) ON DELETE CASCADE,
  person_id  VARCHAR(20) REFERENCES person(id)  ON DELETE CASCADE,
  note       TEXT NOT NULL,
  updated_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY(profile_id, person_id)
);

-- Title notes
CREATE OR REPLACE FUNCTION set_note_title(p_profile_id INT, p_title_id VARCHAR(20), p_note TEXT)
RETURNS VOID
LANGUAGE sql AS $$
  INSERT INTO note_title(profile_id, title_id, note, updated_at)
  VALUES (p_profile_id, p_title_id, p_note, NOW())
  ON CONFLICT (profile_id, title_id)
  DO UPDATE SET note = EXCLUDED.note, updated_at = NOW();
$$;

CREATE OR REPLACE FUNCTION get_note_title(p_profile_id INT, p_title_id VARCHAR(20))
RETURNS TABLE (title_id VARCHAR(20), note TEXT, updated_at TIMESTAMP)
LANGUAGE sql AS $$
  SELECT title_id, note, updated_at
  FROM note_title
  WHERE profile_id = p_profile_id AND title_id = p_title_id;
$$;

CREATE OR REPLACE FUNCTION delete_note_title(p_profile_id INT, p_title_id VARCHAR(20))
RETURNS VOID
LANGUAGE sql AS $$
  DELETE FROM note_title WHERE profile_id = p_profile_id AND title_id = p_title_id;
$$;

-- Person notes
CREATE OR REPLACE FUNCTION set_note_person(p_profile_id INT, p_person_id VARCHAR(20), p_note TEXT)
RETURNS VOID
LANGUAGE sql AS $$
  INSERT INTO note_person(profile_id, person_id, note, updated_at)
  VALUES (p_profile_id, p_person_id, p_note, NOW())
  ON CONFLICT (profile_id, person_id)
  DO UPDATE SET note = EXCLUDED.note, updated_at = NOW();
$$;

CREATE OR REPLACE FUNCTION get_note_person(p_profile_id INT, p_person_id VARCHAR(20))
RETURNS TABLE (person_id VARCHAR(20), note TEXT, updated_at TIMESTAMP)
LANGUAGE sql AS $$
  SELECT person_id, note, updated_at
  FROM note_person
  WHERE profile_id = p_profile_id AND person_id = p_person_id;
$$;

CREATE OR REPLACE FUNCTION delete_note_person(p_profile_id INT, p_person_id VARCHAR(20))
RETURNS VOID
LANGUAGE sql AS $$
  DELETE FROM note_person WHERE profile_id = p_profile_id AND person_id = p_person_id;
$$;


-- ===========================
-- 1.4 Retrieve history
-- ===========================

-- Search history
CREATE OR REPLACE FUNCTION get_search_history(p_profile_id INT, p_limit INT DEFAULT 50)
RETURNS TABLE (searched_at TIMESTAMP, query TEXT)
LANGUAGE sql AS $$
  SELECT created_at, search_query
  FROM search_history
  WHERE profile_id = p_profile_id
  ORDER BY created_at DESC
  LIMIT p_limit;
$$;

-- Rating history (viser titelnavn sammen med rating)
CREATE OR REPLACE FUNCTION get_rating_history(p_profile_id INT, p_limit INT DEFAULT 50)
RETURNS TABLE (rated_at TIMESTAMP, title_id VARCHAR(20), rate INT, primary_title VARCHAR(500))
LANGUAGE sql AS $$
  SELECT rh.created_at, rh.title_id, rh.rating, t.primary_title
  FROM rating_history rh
  LEFT JOIN title t ON t.id = rh.title_id
  WHERE rh.profile_id = p_profile_id
  ORDER BY rh.created_at DESC
  LIMIT p_limit;
$$;
