-- Same as t7 but returning raw numbers for export (all contributors >=8 tasks)
WITH internal AS (
  SELECT id FROM tsip_users WHERE lower(split_part(email,'@',2)) IN
   ('meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')),
tp AS (SELECT t.id AS task_id FROM tsip_tasks t
       JOIN tsip_project_versions pv ON pv.id=t.project_version_id WHERE pv.project_id='sheets'),
fw AS (
  SELECT tst.task_id FROM tsip_state_transitions tst JOIN tp ON tp.task_id=tst.task_id
  WHERE tst.to_state='audit' AND tst.from_state IS DISTINCT FROM 'audit' GROUP BY 1
  HAVING (min(tst.created_at) AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date
         BETWEEN '2026-07-01' AND '2026-08-31'),
cl AS (
  SELECT c.task_id, c.user_id,
         LEAST(GREATEST(EXTRACT(EPOCH FROM (COALESCE(c.last_activity_at,c.closed_at,c.claimed_at)-c.claimed_at))/3600.0,0),12) AS h
  FROM tsip_task_claims c JOIN fw ON fw.task_id=c.task_id
  WHERE c.user_id NOT IN (SELECT id FROM internal)),
pt AS (SELECT task_id, sum(h) AS effort_h FROM cl GROUP BY 1),
own AS (SELECT DISTINCT ON (task_id) task_id, user_id FROM
        (SELECT task_id, user_id, sum(h) AS h FROM cl GROUP BY 1,2) x ORDER BY task_id, h DESC)
SELECT o.user_id::text, COALESCE(u.name,u.email) AS contributor, count(*) AS held,
       percentile_cont(0.50) WITHIN GROUP (ORDER BY pt.effort_h) AS med,
       avg(pt.effort_h) AS mean, percentile_cont(0.90) WITHIN GROUP (ORDER BY pt.effort_h) AS p90,
       max(pt.effort_h) AS worst,
       count(*) FILTER (WHERE pt.effort_h > 40.76) AS outliers
FROM pt JOIN own o ON o.task_id=pt.task_id JOIN tsip_users u ON u.id=o.user_id
GROUP BY o.user_id, u.name, u.email HAVING count(*) >= 8
