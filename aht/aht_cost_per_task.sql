-- =============================================================================
-- CANONICAL COST-GROUNDED AHT  ("how many paid hours does one delivered task
-- cost us, and what is that in dollars")
--
-- Params (Metabase text/date variables):
--   {{project_id}}  e.g. 'chartography'
--   {{start_date}}  inclusive, ET calendar date
--   {{end_date}}    EXCLUSIVE, ET calendar date
--
-- WHY THIS SHAPE -- read before changing anything:
--
-- 1. HOURS BASIS = PAYABLE, not clocked.
--    Ground truth (projects/wintermelon/project.md, "Payable hours", status
--    agreed) names three distinct hour bases and they are NOT interchangeable:
--      * clocked  = timer_sessions.total_seconds        (raw timer)
--      * payable  = payable_time_entries + latest payable_time_revisions
--      * mm_billed = vendor snapshots (multimango only)
--    Payable is the default basis AND the basis money is booked on, so it is
--    the only correct numerator for a COST question. Clocked runs 8-16% higher
--    (breaks, idle, off-task, training cap trims) -- see break_idle_h below.
--    Every pre-existing AHT query in ClaudeContext uses CLOCKED and therefore
--    overstates cost-AHT.
--
-- 2. Day allocation via payable_time_revision_segments, NOT revision.started_at.
--    A session crossing midnight produces several segments; bucketing on the
--    session start collapses them onto the start day and moved 15-31% of spend
--    to the wrong day (bug fixed in project-spend-tracker 2026-08-26).
--
-- 3. Latest revision only (DISTINCT ON ... revision_number DESC). A revision is
--    superseded, not amended; summing all of them double-counts.
--
-- 4. Cost is ACCRUED (payable seconds x in-effect contributor_rates), not the
--    contributor_earnings ledger. The ledger lags (p90 ~21h) so the most recent
--    days read artificially cheap. Accrued reconciles to the ledger within
--    +/-0.7% on chartography and finance-multimodal (verified 2026-08-31), so
--    use accrued and treat the ledger as the audit check, not the source.
--    Rate resolution prefers a user-specific row over the project default.
--
-- 5. DENOMINATOR = FIRST ARRIVAL into a revenue-recognised state, so a task
--    that bounces in and out of delivery is counted once. Per-project because
--    the terminal state differs. This is the unit revenue is billed on, which
--    is what makes the output comparable to a per-task bill rate.
--
-- 6. Timer time carries NO task id, so hours can never be attributed to an
--    individual task. This is a flow ratio (hours in a window / tasks delivered
--    in that window), not a per-task measurement. It is only meaningful over a
--    window long enough that inflow ~ outflow -- see aht_weekly_trend.sql for
--    how badly it swings week to week on a ramping project.
-- =============================================================================
WITH internal AS (
  -- Canonical internal/test exclusion. workada.co is deliberately NOT internal:
  -- pod leads use workada addresses and their hours are real project cost.
  SELECT id FROM tsip_users
  WHERE lower(split_part(email, '@', 2)) IN (
    'meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')
),
revenue_states(project_id, st) AS (
  -- The state whose FIRST entry means "we can bill for this task".
  -- Verified against tsip_prd transitions 2026-08-31. Extend when a project
  -- gains a rate card; an unlisted project yields 0 tasks, not a wrong number.
  VALUES ('chartography',       'delivery_holding'),
         ('chartography',       'delivery_ready'),
         ('chartography',       'done'),
         ('finance-multimodal', 'complete'),
         ('multi-hop-reasoning','delivery_holding'),
         ('multi-hop-reasoning','done')
),
rev AS (
  SELECT DISTINCT ON (ptr.payable_time_entry_id)
         ptr.id, ptr.project_id, ptr.total_seconds, ptr.started_at,
         pte.user_id, pte.timer_session_id
  FROM payable_time_revisions ptr
  JOIN payable_time_entries pte ON pte.id = ptr.payable_time_entry_id
  WHERE ptr.project_id = {{project_id}}
    -- -2 days of slack so a session that STARTED before the window but has
    -- segments inside it is not dropped; the segment-level filter is the real gate.
    AND ptr.started_at >= {{start_date}}::date - 2
  ORDER BY ptr.payable_time_entry_id, ptr.revision_number DESC
),
seg AS (
  SELECT (s.started_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date AS day,
         r.user_id,
         s.total_seconds::numeric AS secs,
         -- Clocked-but-unpayable time on the same session (breaks, idle, off
         -- task, training-cap trim), allocated across the session's days in the
         -- same proportion as payable time so both land on the day worked.
         GREATEST(COALESCE(ses.total_seconds, r.total_seconds) - r.total_seconds, 0)::numeric
           * (s.total_seconds::numeric / NULLIF(r.total_seconds, 0)) AS nonpayable_secs,
         COALESCE(stg.to_stage::text NOT IN ('tasking','off_platform_tasking'), true) AS is_training,
         COALESCE((
           SELECT cr.rate_cents_per_hour
           FROM contributor_rates cr
           WHERE cr.project_id = r.project_id
             AND (cr.user_id = r.user_id OR cr.user_id IS NULL)
             AND cr.effective_from <= r.started_at
             AND (cr.effective_to IS NULL OR cr.effective_to > r.started_at)
           ORDER BY (cr.user_id IS NOT NULL) DESC, cr.effective_from DESC
           LIMIT 1), 0) AS rate_cents
  FROM rev r
  JOIN payable_time_revision_segments s ON s.revision_id = r.id
  LEFT JOIN timer_sessions ses ON ses.id = r.timer_session_id
  LEFT JOIN LATERAL (
    SELECT h.to_stage FROM project_member_stage_history h
    WHERE h.user_id = r.user_id AND h.project_id = r.project_id
      AND h.changed_at <= r.started_at
    ORDER BY h.changed_at DESC LIMIT 1
  ) stg ON true
  WHERE r.user_id NOT IN (SELECT id FROM internal)
),
hours AS (
  SELECT sum(secs) / 3600.0                                    AS payable_h,
         sum(nonpayable_secs) / 3600.0                          AS break_idle_h,
         sum(secs) FILTER (WHERE is_training) / 3600.0           AS training_h,
         sum(secs) FILTER (WHERE NOT is_training) / 3600.0       AS tasking_h,
         sum(secs / 3600.0 * rate_cents) / 100.0                 AS accrued_usd,
         COALESCE(sum(secs) FILTER (WHERE rate_cents = 0), 0) / 3600.0 AS unpriced_h,
         count(DISTINCT user_id)                                 AS contributors
  FROM seg
  WHERE day >= {{start_date}}::date AND day < {{end_date}}::date
),
task_project AS (
  -- tsip_tasks has NO project_id column; bridge via project_version_id.
  SELECT t.id AS task_id, pv.project_id
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
),
first_ready AS (
  SELECT tst.task_id, min(tst.created_at) AS first_ready_at
  FROM tsip_state_transitions tst
  JOIN task_project tp   ON tp.task_id = tst.task_id
  JOIN revenue_states rs ON rs.project_id = tp.project_id AND rs.st = tst.to_state
  WHERE tp.project_id = {{project_id}}
  GROUP BY 1
),
delivered AS (
  SELECT count(*) AS delivered_tasks
  FROM first_ready
  WHERE (first_ready_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date >= {{start_date}}::date
    AND (first_ready_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date <  {{end_date}}::date
)
SELECT
  {{project_id}}                                      AS project_id,
  ROUND(h.payable_h::numeric, 1)                      AS payable_hours,
  ROUND(h.tasking_h::numeric, 1)                      AS tasking_hours,
  ROUND(h.training_h::numeric, 1)                     AS training_hours,
  ROUND(h.break_idle_h::numeric, 1)                   AS break_idle_hours,
  ROUND((100.0 * h.break_idle_h
         / NULLIF(h.payable_h + h.break_idle_h, 0))::numeric, 1) AS pct_clocked_unpayable,
  h.contributors,
  d.delivered_tasks,
  ROUND(h.accrued_usd::numeric, 2)                    AS accrued_cost_usd,
  CASE WHEN h.payable_h > 0
       THEN ROUND((h.accrued_usd / h.payable_h)::numeric, 2) END AS blended_rate_usd_per_hour,

  -- ***** THE AHT FIGURE *****
  CASE WHEN d.delivered_tasks > 0
       THEN ROUND((h.payable_h / d.delivered_tasks)::numeric, 2) END AS aht_payable_hours_per_delivered_task,
  CASE WHEN d.delivered_tasks > 0
       THEN ROUND((h.accrued_usd / d.delivered_tasks)::numeric, 2) END AS cost_per_delivered_task_usd,

  -- DQ guards. Non-zero unpriced hours means the accrued cost is UNDERSTATED
  -- (the zero-fill pitfall); reconcile before quoting the dollar figure.
  ROUND(h.unpriced_h::numeric, 1)                     AS unpriced_hours_dq,
  ROUND((100.0 * h.unpriced_h / NULLIF(h.payable_h, 0))::numeric, 2) AS pct_hours_unpriced_dq
FROM hours h CROSS JOIN delivered d
