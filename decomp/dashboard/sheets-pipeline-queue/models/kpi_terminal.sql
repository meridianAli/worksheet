-- Delivery & Terminal tab KPI row.
WITH live AS (
  SELECT t.id, t.status
  FROM tsip_tasks t JOIN tsip_project_versions pv ON pv.id = t.project_version_id WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status IN ('audit','delivery_holding','delivery_ready','complete','cancelled')
),
cancelled_30d AS (
  SELECT tst.task_id, tst.from_state
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id
  WHERE tst.to_state = 'cancelled' AND tst.created_at >= now() - interval '30 days'
),
audit_scores AS (
  SELECT a.score FROM tsip_audits a JOIN live ON live.id = a.task_id
  WHERE a.audit_type = 'task_pipeline' AND a.score IS NOT NULL AND a.submitted_at >= now() - interval '30 days'
)
SELECT count(*) FILTER (WHERE live.status = 'audit')                        AS in_audit,
       count(*) FILTER (WHERE live.status = 'delivery_holding')             AS delivery_holding,
       count(*) FILTER (WHERE live.status = 'delivery_ready')               AS delivery_ready,
       count(*) FILTER (WHERE live.status = 'complete')                     AS complete,
       (SELECT count(*) FROM cancelled_30d)                                 AS cancelled_30d,
       (SELECT count(*) FROM cancelled_30d WHERE from_state = 'needs_sota_eval') AS cancelled_from_sota_30d,
       (SELECT ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY score)::numeric, 1) FROM audit_scores) AS median_audit_score_30d
FROM live
