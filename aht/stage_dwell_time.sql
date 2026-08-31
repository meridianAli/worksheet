-- STAGE DWELL TIME: where does calendar time actually go?
-- Exact from the transition log -- no attribution needed.
WITH tp AS (
  SELECT t.id AS task_id FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id=t.project_version_id
  WHERE pv.project_id='sheets'
),
ev AS (
  SELECT tst.task_id, tst.to_state AS state, tst.created_at AS entered_at,
         LEAD(tst.created_at) OVER (PARTITION BY tst.task_id ORDER BY tst.created_at) AS left_at
  FROM tsip_state_transitions tst
  JOIN tp ON tp.task_id=tst.task_id
  WHERE tst.from_state IS DISTINCT FROM tst.to_state
),
d AS (
  SELECT state, task_id,
         EXTRACT(EPOCH FROM (left_at - entered_at))/3600.0 AS hrs
  FROM ev
  WHERE left_at IS NOT NULL
    AND entered_at >= '2026-07-01' AND entered_at < '2026-09-01'
)
SELECT state,
       count(*) AS entries,
       count(DISTINCT task_id) AS tasks,
       ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY hrs)::numeric,2)  AS median_h,
       ROUND(percentile_cont(0.9) WITHIN GROUP (ORDER BY hrs)::numeric,1)  AS p90_h,
       ROUND(sum(hrs)::numeric,0) AS total_state_hours
FROM d
GROUP BY state
HAVING count(*) >= 10
ORDER BY sum(hrs) DESC
