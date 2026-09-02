-- SHEETS DECOMP REVIEW QUEUE -- live snapshot of every task currently in decomp_review.
-- Read-only. tsip_prd (Metabase database id 2). Re-run any time for a fresh pull.
-- Note: `sheets` is the project with a state literally named `decomp_review`.
-- `advanced-workbook-project` has a separate `pending_decomp_review` state -- change
-- the two literals below if that is the queue you want.
WITH t AS (
  SELECT t.id, t.status, t.assigned_user_id, t.created_at, t.updated_at,
         t.pooled_at, t.timeout_at
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets'
    AND t.status = 'decomp_review'
    AND t.archived_at IS NULL        -- drop archived; 112 rows incl. archived, 99 live
),
ent AS (   -- most recent entry into the state = start of the current dwell
  SELECT DISTINCT ON (tst.task_id)
         tst.task_id, tst.created_at AS entered_at, tst.from_state, tst.triggered_by
  FROM tsip_state_transitions tst
  JOIN t ON t.id = tst.task_id
  WHERE tst.to_state = 'decomp_review'
  ORDER BY tst.task_id, tst.created_at DESC
),
hist AS (
  SELECT tst.task_id,
         count(*) FILTER (WHERE tst.to_state = 'decomp_review') AS decomp_review_entries,
         count(*) AS transitions
  FROM tsip_state_transitions tst
  JOIN t ON t.id = tst.task_id
  GROUP BY 1
),
att AS (
  SELECT a.task_id, count(*) AS attempts, max(a.submitted_at) AS last_submitted_at
  FROM tsip_attempts a
  JOIN t ON t.id = a.task_id
  GROUP BY 1
)
SELECT t.id AS task_id,
       ent.entered_at,
       ROUND((EXTRACT(EPOCH FROM (now() - ent.entered_at)) / 3600.0)::numeric, 1) AS hours_in_decomp_review,
       ent.from_state AS came_from,
       ent.triggered_by,
       hist.decomp_review_entries,   -- >1 means the task has been round-tripped
       hist.transitions,
       COALESCE(att.attempts, 0) AS attempts,
       att.last_submitted_at,
       t.assigned_user_id,           -- NULL for all 99: review is unclaimed
       t.pooled_at, t.timeout_at, t.created_at, t.updated_at
FROM t
LEFT JOIN ent  ON ent.task_id  = t.id
LEFT JOIN hist ON hist.task_id = t.id
LEFT JOIN att  ON att.task_id  = t.id
ORDER BY ent.entered_at
