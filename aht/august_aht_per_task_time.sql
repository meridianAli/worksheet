-- Step 2: time measured on each of those tasks, from claims on that task
WITH tp AS (
  SELECT t.id AS task_id FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id=t.project_version_id WHERE pv.project_id='sheets'),
fa AS (
  SELECT tst.task_id, min(tst.created_at) AS audit_at
  FROM tsip_state_transitions tst JOIN tp ON tp.task_id=tst.task_id
  WHERE tst.to_state='audit' AND tst.from_state IS DISTINCT FROM 'audit'
  GROUP BY 1
  HAVING (min(tst.created_at) AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date
         BETWEEN '2026-08-01' AND '2026-08-31'),
cred AS (
  SELECT fa.task_id, fa.audit_at,
    (SELECT e.triggered_by FROM tsip_state_transitions e
      WHERE e.task_id = fa.task_id
        AND e.from_state IN ('edit_task','redo_task')
        AND e.from_state IS DISTINCT FROM e.to_state
        AND e.created_at <= fa.audit_at
      ORDER BY e.created_at DESC LIMIT 1) AS user_id
  FROM fa),
pt AS (
  SELECT c.task_id, c.user_id
  FROM cred c
  JOIN tsip_project_members m ON m.user_id=c.user_id AND m.project_id='sheets'
  WHERE m.role::text='prompt_tasker')
SELECT pt.task_id::text, pt.user_id::text,
       ROUND(COALESCE(sum(LEAST(GREATEST(EXTRACT(EPOCH FROM (COALESCE(c.last_activity_at,c.closed_at,c.claimed_at)-c.claimed_at))/3600.0,0),12))
             FILTER (WHERE c.user_id=pt.user_id),0)::numeric,4) AS own_h,
       ROUND(COALESCE(sum(LEAST(GREATEST(EXTRACT(EPOCH FROM (COALESCE(c.last_activity_at,c.closed_at,c.claimed_at)-c.claimed_at))/3600.0,0),12)),0)::numeric,4) AS all_h,
       ROUND(COALESCE(sum(GREATEST(EXTRACT(EPOCH FROM (COALESCE(c.last_activity_at,c.closed_at,c.claimed_at)-c.claimed_at))/3600.0,0))
             FILTER (WHERE c.user_id=pt.user_id),0)::numeric,4) AS own_uncapped,
       count(c.id) AS claims_total,
       count(c.id) FILTER (WHERE c.user_id=pt.user_id) AS claims_own
FROM pt LEFT JOIN tsip_task_claims c ON c.task_id=pt.task_id
GROUP BY 1,2
