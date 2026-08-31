-- =============================================================================
-- AHT WEEKLY TREND -- the stability check.
--
-- Hours land in the week the work happened; acceptances land whenever review
-- and delivery get to them. On a ramping project those are different weeks, so
-- weekly AHT swings hard and NO single week is a trustworthy figure. Use this
-- to decide whether a project is stable enough to quote a point AHT at all.
--
-- On chartography (launched ~2026-08-03) weekly AHT ran 1.69 -> 6.09 -> 11.46
-- -> 6.02 over its first four weeks while the cumulative figure sat at ~6.85.
-- Quote the cumulative/trailing figure, not a week.
--
-- Params: {{project_id}}, {{weeks_back}} (integer, e.g. 8)
-- Excludes the in-progress current week.
-- =============================================================================
WITH internal AS (
  SELECT id FROM tsip_users
  WHERE lower(split_part(email, '@', 2)) IN (
    'meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')
),
revenue_states(project_id, st) AS (
  VALUES ('chartography','delivery_holding'), ('chartography','delivery_ready'),
         ('chartography','done'), ('finance-multimodal','complete'),
         ('multi-hop-reasoning','delivery_holding'), ('multi-hop-reasoning','done')
),
weeks AS (
  SELECT generate_series(
    date_trunc('week', (now() AT TIME ZONE 'America/New_York')::date)
      - ({{weeks_back}} || ' weeks')::interval,
    date_trunc('week', (now() AT TIME ZONE 'America/New_York')::date) - INTERVAL '1 week',
    INTERVAL '1 week')::date AS wk
),
rev AS (
  SELECT DISTINCT ON (ptr.payable_time_entry_id)
         ptr.id, ptr.total_seconds, ptr.started_at, pte.user_id, pte.timer_session_id
  FROM payable_time_revisions ptr
  JOIN payable_time_entries pte ON pte.id = ptr.payable_time_entry_id
  WHERE ptr.project_id = {{project_id}}
  ORDER BY ptr.payable_time_entry_id, ptr.revision_number DESC
),
seg AS (
  SELECT date_trunc('week',
           (s.started_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date)::date AS wk,
         s.total_seconds::numeric AS secs,
         GREATEST(COALESCE(ses.total_seconds, r.total_seconds) - r.total_seconds, 0)::numeric
           * (s.total_seconds::numeric / NULLIF(r.total_seconds, 0)) AS nonpayable_secs,
         s.total_seconds::numeric / 3600.0 * COALESCE((
           SELECT cr.rate_cents_per_hour FROM contributor_rates cr
           WHERE cr.project_id = {{project_id}}
             AND (cr.user_id = r.user_id OR cr.user_id IS NULL)
             AND cr.effective_from <= r.started_at
             AND (cr.effective_to IS NULL OR cr.effective_to > r.started_at)
           ORDER BY (cr.user_id IS NOT NULL) DESC, cr.effective_from DESC
           LIMIT 1), 0) / 100.0 AS usd
  FROM rev r
  JOIN payable_time_revision_segments s ON s.revision_id = r.id
  LEFT JOIN timer_sessions ses ON ses.id = r.timer_session_id
  WHERE r.user_id NOT IN (SELECT id FROM internal)
),
h AS (
  SELECT wk, sum(secs) / 3600.0 AS payable_h,
         sum(secs + nonpayable_secs) / 3600.0 AS clocked_h,
         sum(usd) AS accrued_usd
  FROM seg GROUP BY 1
),
tp AS (
  SELECT t.id AS task_id FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = {{project_id}}
),
first_ready AS (
  SELECT tst.task_id, min(tst.created_at) AS ts
  FROM tsip_state_transitions tst
  JOIN tp ON tp.task_id = tst.task_id
  JOIN revenue_states rs ON rs.project_id = {{project_id}} AND rs.st = tst.to_state
  GROUP BY 1
),
d AS (
  SELECT date_trunc('week',
           (ts AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date)::date AS wk,
         count(*) AS delivered
  FROM first_ready GROUP BY 1
)
SELECT w.wk AS week_start,
       ROUND(h.payable_h::numeric, 0)   AS payable_h,
       ROUND(h.clocked_h::numeric, 0)   AS clocked_h,
       ROUND((100.0 * (h.clocked_h - h.payable_h)
              / NULLIF(h.clocked_h, 0))::numeric, 1) AS pct_clocked_unpayable,
       ROUND(h.accrued_usd::numeric, 0)  AS accrued_usd,
       COALESCE(d.delivered, 0)          AS delivered_tasks,
       ROUND((h.payable_h / NULLIF(d.delivered, 0))::numeric, 2) AS aht_this_week,
       -- Cumulative is the figure to quote: it self-corrects the timing mismatch
       -- between hours spent and tasks accepted as volume accumulates.
       ROUND((sum(h.payable_h) OVER (ORDER BY w.wk)
              / NULLIF(sum(d.delivered) OVER (ORDER BY w.wk), 0))::numeric, 2) AS aht_cumulative,
       ROUND((sum(h.accrued_usd) OVER (ORDER BY w.wk)
              / NULLIF(sum(d.delivered) OVER (ORDER BY w.wk), 0))::numeric, 0) AS cost_per_task_cumulative_usd
FROM weeks w
LEFT JOIN h ON h.wk = w.wk
LEFT JOIN d ON d.wk = w.wk
ORDER BY w.wk
