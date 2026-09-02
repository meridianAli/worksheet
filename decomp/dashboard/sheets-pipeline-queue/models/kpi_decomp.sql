-- Decomp tab KPI row.
WITH live AS (
  SELECT t.id, t.status, t.updated_at
  FROM tsip_tasks t JOIN tsip_project_versions pv ON pv.id = t.project_version_id WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status IN ('needs_decomp','decomp_complexity_check','generating_outline','failed_generating_outline','decomp_review')
),
entered AS (
  SELECT tst.task_id, MAX(tst.created_at) AS entered_state_at
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id AND tst.to_state = live.status GROUP BY 1
),
has_outline AS (
  SELECT DISTINCT a.task_id FROM tsip_attempts a JOIN live ON live.id = a.task_id WHERE a.metadata ? 'task_outline'
),
lm AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.messages
  FROM tsip_attempts a JOIN live ON live.id = a.task_id
  WHERE jsonb_array_length(COALESCE(a.messages, '[]'::jsonb)) > 0
  ORDER BY a.task_id, a.created_at DESC
),
pair AS (
  SELECT lm.task_id,
    (SELECT (ci->'_annotations'->>'fileId')::uuid FROM jsonb_array_elements(lm.messages) msg, jsonb_array_elements(msg->'content') ci
      WHERE ci->'_annotations'->>'field_id' = 'input_workbook' LIMIT 1)  AS in_id,
    (SELECT (ci->'_annotations'->>'fileId')::uuid FROM jsonb_array_elements(lm.messages) msg, jsonb_array_elements(msg->'content') ci
      WHERE ci->'_annotations'->>'field_id' = 'output_workbook' LIMIT 1) AS out_id
  FROM lm
),
big AS (
  SELECT p.task_id FROM pair p JOIN tsip_files fi ON fi.id = p.in_id JOIN tsip_files fo ON fo.id = p.out_id
  WHERE fi.size + fo.size > 4 * 1024 * 1024
),
runs_today AS (
  SELECT count(*) AS runs, count(*) FILTER (WHERE p.input_tokens < 10000) AS empty_runs
  FROM tsip_model_run_progress p
  WHERE p.job_type = 'modal_claude_agent' AND p.project_id = 'sheets'
    AND (p.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date = (now() AT TIME ZONE 'America/New_York')::date
)
SELECT count(*)                                                                                  AS in_family,
       count(*) FILTER (WHERE live.status IN ('decomp_review','failed_generating_outline','decomp_complexity_check')
                          AND ho.task_id IS NULL)                                                AS no_outline,
       (SELECT CASE WHEN runs = 0 THEN NULL ELSE ROUND(100.0 * empty_runs / runs, 0) END FROM runs_today) AS empty_context_runs_today_pct,
       (SELECT runs FROM runs_today)                                                             AS outline_runs_today,
       count(*) FILTER (WHERE b.task_id IS NOT NULL)                                             AS workbooks_over_4mb,
       count(*) FILTER (WHERE COALESCE(e.entered_state_at, live.updated_at) < now() - interval '2 days'
                          AND live.status <> 'needs_decomp')                                     AS waiting_over_2_days
FROM live
LEFT JOIN entered e ON e.task_id = live.id
LEFT JOIN has_outline ho ON ho.task_id = live.id
LEFT JOIN big b ON b.task_id = live.id
