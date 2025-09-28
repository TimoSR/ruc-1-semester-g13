DELETE FROM student
WHERE id IN (SELECT id FROM instructor)
  AND tot_cred = 0;
