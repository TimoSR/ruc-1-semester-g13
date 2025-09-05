-- Insert some demo users
INSERT INTO users (email, name)
VALUES
    ('alice@example.com', 'Alice'),
    ('bob@example.com', 'Bob'),
    ('charlie@example.com', 'Charlie')
ON CONFLICT DO NOTHING;

-- Insert some demo posts
INSERT INTO posts (user_id, title, body, published)
VALUES
    (1, 'Hello World', 'This is Alice''s first post.', TRUE),
    (2, 'Post by Bob', 'Bob shares his thoughts here.', FALSE),
    (3, 'Charlies Notes', 'Charlie leaves some notes.', TRUE);
