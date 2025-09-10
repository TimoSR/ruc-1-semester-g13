WITH c_s AS (
  SELECT id, SUM(credits) as cred_sum
  FROM takes NATURAL JOIN course
  GROUP BY id
)
SELECT c_s.id, c_s.cred_sum
FROM c_s
WHERE cred_sum > 85;
