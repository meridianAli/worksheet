-- Review & Eval tab KPI row.
WITH live AS (
  SELECT t.id, t.status
  FROM tsip_tasks t JOIN tsip_project_versions pv ON pv.id = t.project_version_id WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status IN ('review_gate','failed_review_gate','rubric_eval','initial_rubric_eval','failed_rubric_eval',
                     'failed_initial_rubric_eval','task_review','initial_task_review','failed_task_review',
                     'failed_initial_task_review','beginner_task_review','review_eval_hallucination',
                     'redo_task','edit_task','one_off_edit')
),
fb AS (
  SELECT DISTINCT ON (f.task_id) f.task_id, f.score
  FROM tsip_task_claude_feedback_runs f JOIN live ON live.id = f.task_id
  WHERE f.status = 'completed' ORDER BY f.task_id, f.created_at DESC
),
claims AS (
  SELECT DISTINCT c.task_id FROM tsip_task_claims c JOIN live ON live.id = c.task_id WHERE c.status = 'active'
)
SELECT count(*)                                                        AS in_family,
       count(*) FILTER (WHERE live.status LIKE 'failed_%')             AS in_failed_review_state,
       count(*) FILTER (WHERE live.status = 'redo_task')               AS redo_task,
       count(*) FILTER (WHERE live.status = 'review_eval_hallucination') AS hallucination_queue,
       count(cl.task_id)                                               AS active_claims,
       ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY fb.score)::numeric, 1) AS median_feedback_score
FROM live
LEFT JOIN fb ON fb.task_id = live.id
LEFT JOIN claims cl ON cl.task_id = live.id
