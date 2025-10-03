-- 3

CREATE OR REPLACE FUNCTION rate(p_profile_id INT, p_title_id VARCHAR(20), p_rate INT)
RETURNS TABLE (title_id VARCHAR(20), average_rating FLOAT, num_votes INT)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  INSERT INTO rating(title_id, average_rating, num_votes)
  VALUES (p_title_id, p_rate::float, 1)
  ON CONFLICT ON CONSTRAINT rating_pkey   -- undgår ambiguity
  DO UPDATE SET
    average_rating = ((rating.average_rating * rating.num_votes) + EXCLUDED.average_rating)
                     / (rating.num_votes + 1),
    num_votes      = rating.num_votes + 1
  RETURNING rating.title_id, rating.average_rating, rating.num_votes;
END;
$$;