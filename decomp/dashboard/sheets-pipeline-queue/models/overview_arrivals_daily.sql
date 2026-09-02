-- Overview line: tasks arriving per day (America/New_York) into the three
-- stages that gate throughput. created_at is naive UTC, so it takes both
-- AT TIME ZONE conversions (see decomp/decomp_review_flow.sql).
SELECT (tst.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date AS day_et,
       count(*) FILTER (WHERE tst.to_state = 'decomp_review')   AS into_decomp_review,
       count(*) FILTER (WHERE tst.to_state = 'needs_sota_eval') AS into_needs_sota_eval,
       count(*) FILTER (WHERE tst.to_state = 'delivery_ready')  AS into_delivery_ready,
       count(*) FILTER (WHERE tst.to_state = 'cancelled')       AS into_cancelled
FROM tsip_state_transitions tst
JOIN tsip_tasks t ON t.id = tst.task_id
JOIN tsip_project_versions pv ON pv.id = t.project_version_id AND pv.project_id = 'sheets'
WHERE tst.created_at >= now() - interval '14 days'
  AND tst.to_state IN ('decomp_review','needs_sota_eval','delivery_ready','cancelled')
GROUP BY 1
ORDER BY 1
