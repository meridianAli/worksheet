-- Root-cause query for the "no task_outline" failures on sheets.
--
-- The outline generator is a Modal-hosted Claude workbook agent, logged in
-- tsip_model_run_progress (job_type='modal_claude_agent'). A healthy run reads
-- the workbook and shows ~150k-450k input tokens. A broken run shows ~5,380 --
-- the bare prompt scaffolding with no workbook attached -- and returns 1-8
-- output tokens while still reporting status='completed'.
--
-- 10,000 input tokens is the separator: the two populations are ~5.4k and
-- >=139k, with nothing in between.
SELECT (p.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date AS day_et,
       count(*) AS runs,
       count(*) FILTER (WHERE p.input_tokens < 10000) AS empty_context_runs,
       ROUND(100.0 * count(*) FILTER (WHERE p.input_tokens < 10000) / count(*), 1) AS pct_empty,
       ROUND(percentile_cont(0.5) WITHIN GROUP (
         ORDER BY p.input_tokens) FILTER (WHERE p.input_tokens >= 10000)) AS med_in_healthy,
       ROUND(percentile_cont(0.5) WITHIN GROUP (
         ORDER BY p.output_tokens) FILTER (WHERE p.input_tokens >= 10000)) AS med_out_healthy,
       ROUND(percentile_cont(0.5) WITHIN GROUP (
         ORDER BY p.output_tokens) FILTER (WHERE p.input_tokens < 10000)) AS med_out_empty
FROM tsip_model_run_progress p
WHERE p.job_type = 'modal_claude_agent'
  AND p.project_id = 'sheets'
  AND p.created_at >= now() - interval '21 days'
GROUP BY 1
ORDER BY 1;

-- Proof that the workbook is not at fault: the same file id succeeds elsewhere.
-- Swap in any fileId from a failing task's attempt metadata
-- (metadata->'uploaded_workbooks'->0->>'fileId').
--
--   SELECT p.task_id, p.created_at, p.status, p.input_tokens, p.output_tokens
--   FROM tsip_attempts a
--   JOIN tsip_model_run_progress p ON p.task_id = a.task_id
--   WHERE a.metadata->'uploaded_workbooks' @> '[{"fileId":"<FILE_ID>"}]'::jsonb
--     AND p.job_type = 'modal_claude_agent'
--   ORDER BY p.created_at;
