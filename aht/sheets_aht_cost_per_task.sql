-- =============================================================================
-- SHEETS AHT & COST PER TASK -- the best available proxy for patch-based.
--
-- Patch-based cannot be isolated (see patchbased_identifiability.sql), so this
-- measures the whole `sheets` project. Read it as a BLENDED figure across task
-- varieties, not a patch-based figure.
--
-- Params: {{start_date}}, {{end_date}} (both inclusive, ET calendar dates).
--
-- DENOMINATOR = first entry into `audit`. This is deliberate and load-bearing:
--   * Sheets ground truth (projects/sheets/project.md) makes "Tasks Completed"
--     = entered `audit` the canonical meaning of completed for this project,
--     and notes terminal `complete` is tracked separately.
--   * The platform revenue query uses `audit` as the sheets PASSING state.
--   * The later states are delivery-batch bottlenecked, not work measures.
--     Over 2026-07-01..2026-08-31 the same hours divided by `reached_complete`
--     give 21.8 h/task and by `delivery_holding` 78.8 h/task -- 9x and 33x the
--     entered-audit figure. Those measure delivery cadence, not handling time.
--     Do not swap the denominator without re-reading this note.
--
-- Hours basis, day allocation, latest-revision rule and accrued-vs-ledger
-- reasoning are all identical to aht_cost_per_task.sql -- read that header.
--
-- CAVEAT that does NOT show up in this query: the 2026-08-19 Google DeepMind
-- batch re-delivers 1,721 tasks already delivered to Meta in Feb-Jun. Resold
-- inventory carries ~zero marginal labour, so never divide a period's labour by
-- a delivery count that includes it.
-- =============================================================================
WITH internal AS (
  SELECT id FROM tsip_users
  WHERE lower(split_part(email, '@', 2)) IN (
    'meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')
),
rev AS (
  SELECT DISTINCT ON (ptr.payable_time_entry_id)
         ptr.id, ptr.total_seconds, ptr.started_at, pte.user_id, pte.timer_session_id
  FROM payable_time_revisions ptr
  JOIN payable_time_entries pte ON pte.id = ptr.payable_time_entry_id
  WHERE ptr.project_id = 'sheets'
    AND ptr.started_at >= {{start_date}}::date - 2
  ORDER BY ptr.payable_time_entry_id, ptr.revision_number DESC
),
seg AS (
  SELECT (s.started_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date AS day,
         r.user_id,
         s.total_seconds::numeric AS secs,
         GREATEST(COALESCE(ses.total_seconds, r.total_seconds) - r.total_seconds, 0)::numeric
           * (s.total_seconds::numeric / NULLIF(r.total_seconds, 0)) AS nonpayable_secs,
         COALESCE(stg.to_stage::text NOT IN ('tasking','off_platform_tasking'), true) AS is_training,
         COALESCE((
           SELECT cr.rate_cents_per_hour FROM contributor_rates cr
           WHERE cr.project_id = 'sheets'
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
    WHERE h.user_id = r.user_id AND h.project_id = 'sheets'
      AND h.changed_at <= r.started_at
    ORDER BY h.changed_at DESC LIMIT 1
  ) stg ON true
  WHERE r.user_id NOT IN (SELECT id FROM internal)
),
hours AS (
  SELECT sum(secs) / 3600.0                                  AS payable_h,
         sum(nonpayable_secs) / 3600.0                        AS break_idle_h,
         sum(secs) FILTER (WHERE is_training) / 3600.0         AS training_h,
         sum(secs / 3600.0 * rate_cents) / 100.0               AS accrued_usd,
         COALESCE(sum(secs) FILTER (WHERE rate_cents = 0), 0) / 3600.0 AS unpriced_h,
         count(DISTINCT user_id)                               AS contributors
  FROM seg
  WHERE day >= {{start_date}}::date AND day <= {{end_date}}::date
),
tp AS (
  SELECT t.id AS task_id FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets'
),
first_audit AS (
  SELECT tst.task_id, min(tst.created_at) AS ts
  FROM tsip_state_transitions tst
  JOIN tp ON tp.task_id = tst.task_id
  WHERE tst.to_state = 'audit' AND tst.from_state IS DISTINCT FROM 'audit'
  GROUP BY 1
),
delivered AS (
  SELECT count(*) AS tasks_reaching_audit
  FROM first_audit
  WHERE (ts AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date >= {{start_date}}::date
    AND (ts AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date <= {{end_date}}::date
)
SELECT 'sheets (all varieties -- NOT patch-based only)' AS scope,
       ROUND(h.payable_h::numeric, 1)      AS payable_hours,
       ROUND(h.training_h::numeric, 1)     AS training_hours,
       ROUND(h.break_idle_h::numeric, 1)   AS break_idle_hours,
       h.contributors,
       d.tasks_reaching_audit,
       ROUND(h.accrued_usd::numeric, 0)    AS accrued_cost_usd,
       ROUND((h.accrued_usd / NULLIF(h.payable_h, 0))::numeric, 2) AS blended_rate_usd_per_hour,
       ROUND((h.payable_h  / NULLIF(d.tasks_reaching_audit, 0))::numeric, 2) AS aht_payable_hours_per_task,
       ROUND((h.accrued_usd / NULLIF(d.tasks_reaching_audit, 0))::numeric, 0) AS cost_per_task_usd,
       ROUND(h.unpriced_h::numeric, 1)     AS unpriced_hours_dq
FROM hours h CROSS JOIN delivered d
