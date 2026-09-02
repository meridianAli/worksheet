-- Delivery & Terminal tab bar: cancelled sheets tasks in the last 30 days by
-- the state they were cancelled from (SOTA too-easy cancellations dominate).
SELECT tst.from_state AS cancelled_from,
       count(*) AS cancelled_30d
FROM tsip_state_transitions tst
JOIN tsip_tasks t ON t.id = tst.task_id
JOIN tsip_project_versions pv ON pv.id = t.project_version_id AND pv.project_id = 'sheets'
WHERE tst.to_state = 'cancelled' AND tst.created_at >= now() - interval '30 days'
GROUP BY 1
ORDER BY 2 DESC
