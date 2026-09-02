-- Feeds the dashboard's Stage dropdown: every populated, non-archived sheets
-- state with its family (the tab that shows it) and the live count.
WITH live AS (
  SELECT t.status
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
)
SELECT status,
       CASE
         WHEN status IN ('needs_decomp','decomp_complexity_check','generating_outline',
                         'failed_generating_outline','decomp_review')                      THEN 'Decomp'
         WHEN status IN ('generating_prompt','failed_generating_prompt','generating_rubric',
                         'failed_generating_rubric','regenerating_rubric')                 THEN 'Prompt & Rubric'
         WHEN status = 'needs_sota_eval'                                                     THEN 'SOTA gate'
         WHEN status LIKE 'calibration_%'                                                    THEN 'Calibration'
         WHEN status IN ('audit','delivery_holding','delivery_ready','complete','cancelled') THEN 'Delivery & Terminal'
         ELSE 'Review & Eval'
       END AS family,
       (status LIKE 'failed_%') AS is_failed,
       count(*) AS live_tasks
FROM live
GROUP BY 1
ORDER BY 4 DESC
