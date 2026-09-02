-- Calibration tab KPI row.
WITH live AS (
  SELECT t.id, t.status
  FROM tsip_tasks t JOIN tsip_project_versions pv ON pv.id = t.project_version_id WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status LIKE 'calibration_%'
),
failed_once AS (
  SELECT DISTINCT a.task_id FROM tsip_attempts a JOIN live ON live.id = a.task_id
  WHERE a.metadata->>'calibration_failed_once' = 'true'
)
SELECT count(*)                                                          AS in_family,
       count(*) FILTER (WHERE live.status = 'calibration_graded')        AS graded,
       count(fo.task_id)                                                 AS failed_once,
       count(*) FILTER (WHERE live.status = 'calibration_manual_review') AS manual_review,
       count(*) FILTER (WHERE live.status = 'calibration_available')     AS available_to_claim
FROM live LEFT JOIN failed_once fo ON fo.task_id = live.id
