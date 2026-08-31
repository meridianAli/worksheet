-- Per-task effort DISTRIBUTION, computed server-side (no row-limit truncation).
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
pt AS (SELECT task_id, sum(h) AS effort_h, count(DISTINCT user_id) AS people FROM cl GROUP BY 1),
rd AS (
  SELECT fw.task_id, count(*) FILTER (WHERE x.to_state='redo_task' AND x.from_state IS DISTINCT FROM 'redo_task') AS redos
  FROM fw JOIN tsip_state_transitions x ON x.task_id=fw.task_id GROUP BY 1),
j AS (SELECT pt.task_id, pt.effort_h, pt.people, COALESCE(rd.redos,0) AS redos FROM pt LEFT JOIN rd ON rd.task_id=pt.task_id)
SELECT count(*) AS tasks,
       ROUND(avg(effort_h)::numeric,2) AS mean_h,
       ROUND(percentile_cont(0.50) WITHIN GROUP (ORDER BY effort_h)::numeric,2) AS median_h,
       ROUND(percentile_cont(0.25) WITHIN GROUP (ORDER BY effort_h)::numeric,2) AS p25_h,
       ROUND(percentile_cont(0.75) WITHIN GROUP (ORDER BY effort_h)::numeric,2) AS p75_h,
       ROUND(percentile_cont(0.90) WITHIN GROUP (ORDER BY effort_h)::numeric,2) AS p90_h,
       ROUND(percentile_cont(0.95) WITHIN GROUP (ORDER BY effort_h)::numeric,2) AS p95_h,
       ROUND(percentile_cont(0.99) WITHIN GROUP (ORDER BY effort_h)::numeric,2) AS p99_h,
       ROUND(max(effort_h)::numeric,2) AS max_h,
       ROUND(stddev_pop(effort_h)::numeric,2) AS sd_h,
       ROUND(sum(effort_h)::numeric,0) AS total_h,
       ROUND(avg(redos)::numeric,2) AS mean_redos,
       ROUND(avg(people)::numeric,2) AS mean_people
FROM j
