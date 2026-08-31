-- THE OUTLIER TASKS: worst 45 by effort, with who held them. Scale factor applied
-- in analysis (claim-hours -> payable-hour equivalents).
WITH internal AS (
  SELECT id FROM tsip_users WHERE lower(split_part(email,'@',2)) IN
   ('meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')),
tp AS (SELECT t.id AS task_id, t.status FROM tsip_tasks t
       JOIN tsip_project_versions pv ON pv.id=t.project_version_id WHERE pv.project_id='sheets'),
fw AS (
  SELECT tst.task_id, min(tst.created_at) AS audit_at, min(tst.created_at) AS a2
  FROM tsip_state_transitions tst JOIN tp ON tp.task_id=tst.task_id
  WHERE tst.to_state='audit' AND tst.from_state IS DISTINCT FROM 'audit' GROUP BY 1
  HAVING (min(tst.created_at) AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date
         BETWEEN '2026-07-01' AND '2026-08-31'),
cl AS (
  SELECT c.task_id, c.user_id,
         LEAST(GREATEST(EXTRACT(EPOCH FROM (COALESCE(c.last_activity_at,c.closed_at,c.claimed_at)-c.claimed_at))/3600.0,0),12) AS h
  FROM tsip_task_claims c JOIN fw ON fw.task_id=c.task_id
  WHERE c.user_id NOT IN (SELECT id FROM internal)),
pt AS (SELECT task_id, sum(h) AS effort_h, count(DISTINCT user_id) AS people, count(*) AS claims FROM cl GROUP BY 1),
own AS (SELECT DISTINCT ON (task_id) task_id, user_id, h FROM
        (SELECT task_id, user_id, sum(h) AS h FROM cl GROUP BY 1,2) x ORDER BY task_id, h DESC),
rd AS (SELECT fw.task_id,
         count(*) FILTER (WHERE x.to_state='redo_task' AND x.from_state IS DISTINCT FROM 'redo_task') AS redos
       FROM fw JOIN tsip_state_transitions x ON x.task_id=fw.task_id GROUP BY 1),
fe AS (
  SELECT x.task_id, min(x.created_at) AS first_edit
  FROM tsip_state_transitions x JOIN fw ON fw.task_id=x.task_id
  WHERE x.to_state='edit_task' GROUP BY 1),
elapsed AS (
  SELECT fw.task_id, EXTRACT(EPOCH FROM (fw.audit_at - fe.first_edit))/86400.0 AS days
  FROM fw JOIN fe ON fe.task_id=fw.task_id)
SELECT left(pt.task_id::text,8) AS task,
       COALESCE(u.name,u.email) AS main_holder,
       ROUND(pt.effort_h::numeric,1) AS claim_h,
       ROUND((o.h)::numeric,1) AS holder_h,
       pt.people, pt.claims, COALESCE(rd.redos,0) AS redos,
       ROUND(el.days::numeric,1) AS elapsed_days
FROM pt
LEFT JOIN own o ON o.task_id=pt.task_id
LEFT JOIN tsip_users u ON u.id=o.user_id
LEFT JOIN rd ON rd.task_id=pt.task_id
LEFT JOIN elapsed el ON el.task_id=pt.task_id
ORDER BY pt.effort_h DESC
LIMIT 45
