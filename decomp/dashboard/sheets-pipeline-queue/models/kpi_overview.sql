-- Overview KPI row (single row, one column per tile).
WITH live AS (
  SELECT t.id, t.status, t.updated_at
  FROM tsip_tasks t JOIN tsip_project_versions pv ON pv.id = t.project_version_id WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
),
entered AS (
  SELECT tst.task_id, MAX(tst.created_at) AS entered_state_at
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id AND tst.to_state = live.status
  GROUP BY 1
)
SELECT count(*)                                                                        AS live_tasks,
       count(*) FILTER (WHERE live.status NOT IN ('audit','delivery_holding','delivery_ready','complete','cancelled')) AS in_pipeline,
       count(*) FILTER (WHERE live.status LIKE 'failed_%')                              AS blocked_in_failed_state,
       count(*) FILTER (WHERE live.status = 'needs_sota_eval')                          AS waiting_on_sota,
       count(*) FILTER (WHERE (e.entered_state_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date
                              = (now() AT TIME ZONE 'America/New_York')::date)          AS entered_stage_today_et
FROM live LEFT JOIN entered e ON e.task_id = live.id
