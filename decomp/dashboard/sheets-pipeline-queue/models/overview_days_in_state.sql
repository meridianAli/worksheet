-- Overview bar: median days the live tasks have sat in their current state,
-- per state. Entered-at is the last transition into the state (falls back to
-- tasks.updated_at for tasks that predate transition logging).
WITH live AS (
  SELECT t.id, t.status, t.updated_at
  FROM tsip_tasks t JOIN tsip_project_versions pv ON pv.id = t.project_version_id WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
),
entered AS (
  SELECT tst.task_id, MAX(tst.created_at) AS entered_state_at
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id AND tst.to_state = live.status
  GROUP BY 1
)
SELECT live.status,
       count(*) AS live_tasks,
       ROUND(percentile_cont(0.5) WITHIN GROUP (
         ORDER BY EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 86400.0)::numeric, 1) AS median_days_in_state,
       ROUND(MAX(EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 86400.0)::numeric, 1) AS oldest_days_in_state
FROM live LEFT JOIN entered e ON e.task_id = live.id
GROUP BY 1
ORDER BY 3 DESC
