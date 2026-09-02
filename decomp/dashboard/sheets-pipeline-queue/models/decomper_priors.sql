-- Per-decomper "too easy" prior: share of the decomper's SOTA-scored sheets
-- tasks in the last 60 days that landed in the Foundational or Intermediate
-- bucket. Joined into the SOTA gate tab to predict what will be released.
-- Decomper = the user who fired the last SUBMIT_DECOMP transition on the task.
WITH scored AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.metadata->>'sota_bucket' AS bucket, a.submitted_at
  FROM tsip_attempts a
  JOIN tsip_tasks t ON t.id = a.task_id
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id AND pv.project_id = 'sheets'
  WHERE a.metadata ? 'sota_bucket'
    AND a.submitted_at >= now() - interval '60 days'
  ORDER BY a.task_id, a.submitted_at DESC
),
decomper AS (
  SELECT DISTINCT ON (tst.task_id) tst.task_id, tst.triggered_by AS user_id
  FROM tsip_state_transitions tst
  JOIN scored s ON s.task_id = tst.task_id
  WHERE tst.event = 'SUBMIT_DECOMP'
  ORDER BY tst.task_id, tst.created_at DESC
)
SELECT u.email AS decomper_email,
       count(*) AS scored_tasks,
       count(*) FILTER (WHERE s.bucket IN ('Foundational','Intermediate')) AS too_easy_tasks,
       ROUND(100.0 * count(*) FILTER (WHERE s.bucket IN ('Foundational','Intermediate')) / count(*), 1) AS too_easy_pct,
       count(*) FILTER (WHERE s.bucket = 'Foundational') AS foundational,
       count(*) FILTER (WHERE s.bucket = 'Intermediate') AS intermediate,
       count(*) FILTER (WHERE s.bucket = 'Challenging')  AS challenging,
       count(*) FILTER (WHERE s.bucket = 'Difficult')    AS difficult
FROM scored s
JOIN decomper d ON d.task_id = s.task_id
JOIN tsip_users u ON u.id = d.user_id
GROUP BY 1
ORDER BY 2 DESC
