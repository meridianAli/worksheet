-- Overview bar: live sheets tasks by pipeline state (the rebuilt
-- "Sheets: tasks by pipeline state (live)" card), coloured by family in the
-- dashboard. Honors the Stage filter so the bar and the tables agree.
WITH b AS (
  SELECT t.status,
         CASE
           WHEN t.status IN ('needs_decomp','decomp_complexity_check','generating_outline',
                             'failed_generating_outline','decomp_review')                      THEN 'Decomp'
           WHEN t.status IN ('generating_prompt','failed_generating_prompt','generating_rubric',
                             'failed_generating_rubric','regenerating_rubric')                 THEN 'Prompt & Rubric'
           WHEN t.status = 'needs_sota_eval'                                                     THEN 'SOTA gate'
           WHEN t.status LIKE 'calibration_%'                                                    THEN 'Calibration'
           WHEN t.status IN ('audit','delivery_holding','delivery_ready','complete','cancelled') THEN 'Delivery & Terminal'
           ELSE 'Review & Eval'
         END AS family,
         (t.status LIKE 'failed_%') AS is_failed
  FROM tsip_tasks t JOIN tsip_project_versions pv ON pv.id = t.project_version_id WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
)
SELECT b.status, b.family, b.is_failed, count(*) AS live_tasks
FROM b
WHERE 1 = 1
  [[AND b.status = {{stage}}]]
GROUP BY 1, 2, 3
ORDER BY 4 DESC
