-- Decomp review flow: how fast the queue turns over, and where tasks go next.
-- sheets only (the only project with a live decomp_review state).
--
-- Day is bucketed in America/New_York. created_at is a naive UTC timestamp, so
-- it needs BOTH conversions ('AT TIME ZONE UTC' to label it, then to ET);
-- a single 'AT TIME ZONE America/New_York' shifts it the wrong way and
-- produces tomorrow's date.
WITH ev AS (
  SELECT tst.task_id, tst.to_state, tst.created_at,
         LEAD(tst.to_state) OVER (PARTITION BY tst.task_id ORDER BY tst.created_at) AS next_state,
         LEAD(tst.created_at) OVER (PARTITION BY tst.task_id ORDER BY tst.created_at) AS left_at
  FROM tsip_state_transitions tst
  JOIN tsip_tasks t ON t.id = tst.task_id
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id AND pv.project_id = 'sheets'
), r AS (
  SELECT * FROM ev WHERE to_state = 'decomp_review' AND created_at >= now() - interval '7 days'
)
SELECT (created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date AS day_et,
       count(*) AS entered,
       count(left_at) AS exited,
       ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (left_at-created_at))/3600.0)::numeric,1) AS median_dwell_h,
       count(*) FILTER (WHERE next_state='generating_prompt') AS to_generating_prompt,
       count(*) FILTER (WHERE next_state='generating_outline') AS back_to_outline,
       count(*) FILTER (WHERE next_state='cancelled') AS cancelled,
       count(*) FILTER (WHERE next_state NOT IN ('generating_prompt','generating_outline','cancelled')) AS other
FROM r GROUP BY 1 ORDER BY 1
