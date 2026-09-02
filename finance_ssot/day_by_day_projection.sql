-- Finance SSOT | Day by Day Production + trailing 3-day average + projection
-- Metrics as ROWS, dates as COLUMNS. Days in America/New_York.
--
-- Rows
--   Produced                         Sheets tasks entering `audit` that day (first entry per task)
--   Qualifying                       see the `qualifying` CTE  <-- SWAP IN THE EXISTING DEFINITION
--   Yield %                          Qualifying / Produced
--   Trailing 3-Day Avg Qualifying    average Qualifying over days n-1, n-2, n-3
--                                    (three complete days before n; the partial current day is
--                                    excluded so it never drags the average down)
--   Cumulative Qualifying            running total since the ramp plan start
--   Projected Cumulative Qualifying  actual cumulative through yesterday, then
--                                    yesterday's cumulative + trailing avg x days ahead
--   Ramp Plan                        cumulativeAcceptedTasks from the latest Sheets ramp plan
--
-- Window: edit `win`, then add/remove the max(value) FILTER (...) lines at the bottom.

WITH win AS (
  SELECT '2026-08-26'::date AS start_day, '2026-09-10'::date AS end_day
),
today AS (
  SELECT (now() AT TIME ZONE 'America/New_York')::date AS today
),
ramp_plan AS (
  SELECT (w->>'weekStart')::date               AS day,
         (w->>'cumulativeAcceptedTasks')::int  AS plan_cum_qualifying
  FROM tsip_ramp_plan_revisions r
  CROSS JOIN LATERAL jsonb_array_elements(r.weeks) AS w
  WHERE r.project_id = 'sheets'
    AND r.revision = (SELECT max(revision) FROM tsip_ramp_plan_revisions WHERE project_id = 'sheets')
),
ev AS (
  SELECT (st.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date AS day,
         st.task_id, st.event, st.from_state, st.to_state
  FROM tsip_state_transitions st
  JOIN tsip_tasks t             ON t.id  = st.task_id
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets'
    AND st.from_state IS DISTINCT FROM st.to_state
    -- bound the scan: nothing before the ramp plan start matters here
    AND st.created_at >= (SELECT min(day) FROM ramp_plan) - interval '1 day'
),
produced AS (
  -- Produced = first time a task enters audit
  SELECT task_id, min(day) AS day
  FROM ev
  WHERE to_state = 'audit'
  GROUP BY task_id
),
qualifying AS (
  -- >>> PLACEHOLDER. Replace the body with the dashboard's existing "Qualifying" rule.
  -- Must return one row per qualifying task with the ET day it qualified.
  -- The placeholder below counts audit entries whose task never needed a redo.
  SELECT p.task_id, p.day
  FROM produced p
  WHERE NOT EXISTS (SELECT 1 FROM ev e WHERE e.task_id = p.task_id AND e.to_state = 'redo_task')
),
-- Every day from the plan start through the end of the window, so the cumulative
-- includes history before the visible window and the trailing average has data
-- for the first visible days.
days AS (
  SELECT generate_series(
           LEAST((SELECT min(day) FROM ramp_plan), (SELECT start_day FROM win)),
           (SELECT end_day FROM win),
           interval '1 day')::date AS day
),
produced_by_day   AS (SELECT day, count(*) AS n FROM produced   GROUP BY day),
qualifying_by_day AS (SELECT day, count(*) AS n FROM qualifying GROUP BY day),
daily AS (
  SELECT d.day,
         COALESCE(p.n, 0) AS produced,
         COALESCE(q.n, 0) AS qualifying
  FROM days d
  LEFT JOIN produced_by_day   p ON p.day = d.day
  LEFT JOIN qualifying_by_day q ON q.day = d.day
),
rolled AS (
  SELECT d.day,
         CASE WHEN d.day <= t.today THEN d.produced   END AS produced,
         CASE WHEN d.day <= t.today THEN d.qualifying END AS qualifying,
         CASE WHEN d.day <= t.today THEN sum(d.qualifying) OVER (ORDER BY d.day) END AS cum_qualifying,
         -- trailing average over n-1 .. n-3, complete days only
         avg(CASE WHEN d.day < t.today THEN d.qualifying END)
           OVER (ORDER BY d.day ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) AS trailing_avg
  FROM daily d
  CROSS JOIN today t
),
anchor AS (
  -- yesterday = last complete day; project forward from its cumulative at the
  -- trailing 3-day rate (avg of n-1..n-3 relative to today)
  SELECT r.day AS anchor_day,
         r.cum_qualifying AS anchor_cum,
         (SELECT avg(x.qualifying) FROM rolled x
           WHERE x.day BETWEEN t.today - 3 AND t.today - 1) AS proj_rate
  FROM rolled r CROSS JOIN today t
  WHERE r.day = t.today - 1
),
projected AS (
  SELECT r.*,
         CASE WHEN r.day <= a.anchor_day THEN r.cum_qualifying
              ELSE a.anchor_cum + round(a.proj_rate * (r.day - a.anchor_day))
         END AS projected_cum
  FROM rolled r CROSS JOIN anchor a
),
metrics AS (
  SELECT 1 AS sort_order, 'Produced' AS metric, day, produced::numeric AS value FROM projected
  UNION ALL
  SELECT 2, 'Qualifying',                      day, qualifying::numeric                              FROM projected
  UNION ALL
  SELECT 3, 'Yield %',                         day, round(100.0 * qualifying / NULLIF(produced, 0))  FROM projected
  UNION ALL
  SELECT 4, 'Trailing 3-Day Avg Qualifying',   day, CASE WHEN day <= (SELECT today FROM today)
                                                         THEN round(trailing_avg, 1) END            FROM projected
  UNION ALL
  SELECT 5, 'Cumulative Qualifying',           day, cum_qualifying                                   FROM projected
  UNION ALL
  SELECT 6, 'Projected Cumulative Qualifying', day, projected_cum                                    FROM projected
  UNION ALL
  SELECT 7, 'Ramp Plan',                       day, plan_cum_qualifying                              FROM ramp_plan
)
SELECT metric,
       max(value) FILTER (WHERE day = '2026-08-26') AS "8/26",
       max(value) FILTER (WHERE day = '2026-08-27') AS "8/27",
       max(value) FILTER (WHERE day = '2026-08-28') AS "8/28",
       max(value) FILTER (WHERE day = '2026-08-29') AS "8/29",
       max(value) FILTER (WHERE day = '2026-08-30') AS "8/30",
       max(value) FILTER (WHERE day = '2026-08-31') AS "8/31",
       max(value) FILTER (WHERE day = '2026-09-01') AS "9/1",
       max(value) FILTER (WHERE day = '2026-09-02') AS "9/2",
       max(value) FILTER (WHERE day = '2026-09-03') AS "9/3",
       max(value) FILTER (WHERE day = '2026-09-04') AS "9/4",
       max(value) FILTER (WHERE day = '2026-09-05') AS "9/5",
       max(value) FILTER (WHERE day = '2026-09-06') AS "9/6",
       max(value) FILTER (WHERE day = '2026-09-07') AS "9/7",
       max(value) FILTER (WHERE day = '2026-09-08') AS "9/8",
       max(value) FILTER (WHERE day = '2026-09-09') AS "9/9",
       max(value) FILTER (WHERE day = '2026-09-10') AS "9/10"
FROM metrics
WHERE day BETWEEN (SELECT start_day FROM win) AND (SELECT end_day FROM win)
GROUP BY sort_order, metric
ORDER BY sort_order
