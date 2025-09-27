DELETE FROM student
WHERE tot_cred = 0
  AND id IN (SELECT id FROM instructor)