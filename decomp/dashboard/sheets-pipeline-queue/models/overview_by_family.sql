-- Overview bar: live sheets tasks by stage family (one bar per dashboard tab).
SELECT CASE
         WHEN t.status IN ('needs_decomp','decomp_complexity_check','generating_outline',
                           'failed_generating_outline','decomp_review')                      THEN 'Decomp'
         WHEN t.status IN ('generating_prompt','failed_generating_prompt','generating_rubric',
                           'failed_generating_rubric','regenerating_rubric')                 THEN 'Prompt & Rubric'
         WHEN t.status = 'needs_sota_eval'                                                     THEN 'SOTA gate'
         WHEN t.status LIKE 'calibration_%'                                                    THEN 'Calibration'
         WHEN t.status IN ('audit','delivery_holding','delivery_ready','complete','cancelled') THEN 'Delivery & Terminal'
         ELSE 'Review & Eval'
       END AS family,
       count(*) AS live_tasks,
       count(*) FILTER (WHERE t.status LIKE 'failed_%') AS in_failed_state
FROM tsip_tasks t JOIN tsip_project_versions pv ON pv.id = t.project_version_id WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
GROUP BY 1
ORDER BY 2 DESC
