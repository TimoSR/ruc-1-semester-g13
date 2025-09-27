INSERT INTO student (id, name, dept_name, tot_cred)
SELECT id, name, dept_name, 0
FROM instructor;
