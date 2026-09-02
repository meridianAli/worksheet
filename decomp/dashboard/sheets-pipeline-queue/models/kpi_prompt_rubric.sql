-- Prompt & Rubric tab KPI row.
WITH live AS (
  SELECT t.id, t.status, t.updated_at
  FROM tsip_tasks t JOIN tsip_project_versions pv ON pv.id = t.project_version_id WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status IN ('generating_prompt','failed_generating_prompt','generating_rubric','failed_generating_rubric','regenerating_rubric')
),
entered AS (
  SELECT tst.task_id, MAX(tst.created_at) AS entered_state_at,
         count(*) FILTER (WHERE tst.to_state = 'regenerating_rubric') AS regen_loops
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id
  GROUP BY 1
)
SELECT count(*)                                                              AS in_family,
       count(*) FILTER (WHERE live.status = 'failed_generating_prompt')      AS failed_prompt,
       count(*) FILTER (WHERE live.status = 'failed_generating_rubric')      AS failed_rubric,
       count(*) FILTER (WHERE live.status = 'regenerating_rubric' AND e.regen_loops >= 2) AS regen_loops_2_plus,
       ROUND(percentile_cont(0.5) WITHIN GROUP (
         ORDER BY EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 60.0)::numeric) AS median_minutes_in_state
FROM live LEFT JOIN entered e ON e.task_id = live.id
