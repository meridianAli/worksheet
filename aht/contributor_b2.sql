-- audit credit: task's first audit arrival -> last person out of edit/redo before it
WITH fa AS (
  SELECT tst.task_id, min(tst.created_at) AS audit_at
  FROM tsip_state_transitions tst
  JOIN tsip_tasks t ON t.id=tst.task_id
  JOIN tsip_project_versions pv ON pv.id=t.project_version_id
  WHERE pv.project_id='sheets' AND tst.to_state='audit'
    AND tst.from_state IS DISTINCT FROM 'audit'
  GROUP BY 1
),
fw AS (
  SELECT * FROM fa
  WHERE (audit_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date
        BETWEEN '2026-07-01' AND '2026-08-31'
),
cred AS (
  SELECT fw.task_id, fw.audit_at,
         (SELECT e.triggered_by FROM tsip_state_transitions e
           WHERE e.task_id=fw.task_id
             AND e.from_state IN ('edit_task','redo_task')
             AND e.from_state IS DISTINCT FROM e.to_state
             AND e.created_at <= fw.audit_at
           ORDER BY e.created_at DESC LIMIT 1) AS user_id,
         (SELECT count(*) FROM tsip_state_transitions r
           WHERE r.task_id=fw.task_id AND r.to_state='redo_task'
             AND r.from_state IS DISTINCT FROM 'redo_task') AS redos
  FROM fw
)
SELECT user_id::text, count(*) AS tasks_to_audit, sum(redos) AS redo_events_on_their_tasks
FROM cred WHERE user_id IS NOT NULL GROUP BY 1
