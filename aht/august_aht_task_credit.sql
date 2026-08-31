-- Step 1: August tasks credited to a strict prompt_tasker (small result set)
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
  FROM fa)
SELECT c.task_id::text, c.user_id::text, COALESCE(u.name,u.email) AS contributor
FROM cred c
JOIN tsip_project_members m ON m.user_id=c.user_id AND m.project_id='sheets'
JOIN tsip_users u ON u.id=c.user_id
WHERE m.role::text='prompt_tasker'
