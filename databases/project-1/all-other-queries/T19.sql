WITH credit_sum AS (
    SELECT id, SUM(credits) as c_sum
    FROM takes NATURAL JOIN course
    GROUP BY id
)
SELECT id, tot_cred, c_sum
FROM student natural join credit_sum
WHERE tot_cred <> c_sum;
