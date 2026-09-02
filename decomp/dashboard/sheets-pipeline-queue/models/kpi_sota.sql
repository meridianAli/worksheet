-- SOTA gate KPI row. Expected too-easy share = mean of the decomper priors
-- (60-day Foundational+Intermediate rate) over the tasks waiting.
WITH live AS (
  SELECT t.id, t.status, t.updated_at
  FROM tsip_tasks t JOIN tsip_project_versions pv ON pv.id = t.project_version_id WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status = 'needs_sota_eval'
),
entered AS (
  SELECT tst.task_id, MAX(tst.created_at) AS entered_state_at
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id AND tst.to_state = live.status GROUP BY 1
),
la AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.metadata->>'sota_bucket' AS bucket
  FROM tsip_attempts a JOIN live ON live.id = a.task_id ORDER BY a.task_id, a.created_at DESC
),
decomp_all AS (
  SELECT DISTINCT ON (tst.task_id) tst.task_id, tst.triggered_by AS user_id
  FROM tsip_state_transitions tst
  JOIN tsip_tasks t ON t.id = tst.task_id
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id AND pv.project_id = 'sheets'
  WHERE tst.event = 'SUBMIT_DECOMP' AND tst.created_at >= now() - interval '60 days'
  ORDER BY tst.task_id, tst.created_at DESC
),
scored AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.metadata->>'sota_bucket' AS bucket
  FROM tsip_attempts a JOIN decomp_all d ON d.task_id = a.task_id
  WHERE a.metadata ? 'sota_bucket'
  ORDER BY a.task_id, a.submitted_at DESC NULLS LAST, a.created_at DESC
),
prior AS (
  SELECT d.user_id, 100.0 * count(*) FILTER (WHERE s.bucket IN ('Foundational','Intermediate')) / count(*) AS too_easy_pct
  FROM scored s JOIN decomp_all d ON d.task_id = s.task_id GROUP BY 1
),
live_decomper AS (
  SELECT DISTINCT ON (tst.task_id) tst.task_id, tst.triggered_by AS user_id
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id
  WHERE tst.event = 'SUBMIT_DECOMP' ORDER BY tst.task_id, tst.created_at DESC
)
SELECT count(*)                                                         AS waiting_on_sota,
       count(*) FILTER (WHERE la.bucket IS NOT NULL)                    AS scored_not_released,
       ROUND(AVG(pr.too_easy_pct)::numeric, 0)                          AS expected_too_easy_pct,
       ROUND(percentile_cont(0.5) WITHIN GROUP (
         ORDER BY EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 86400.0)::numeric, 1) AS median_wait_days,
       ROUND(MAX(EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 86400.0)::numeric, 1) AS oldest_wait_days
FROM live
LEFT JOIN entered e ON e.task_id = live.id
LEFT JOIN la ON la.task_id = live.id
LEFT JOIN live_decomper ld ON ld.task_id = live.id
LEFT JOIN prior pr ON pr.user_id = ld.user_id
