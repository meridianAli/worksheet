-- =============================================================================
-- AHT DEFINITION AUDIT -- run this BEFORE quoting any AHT number.
--
-- Purpose: show, for one project, what "AHT" comes out as under each of the
-- definitions already in use across ClaudeContext. On chartography (lifetime,
-- as of 2026-08-31) these span 2.37 -> 7.97 h/task -- a 3.4x spread from
-- definition choice alone. If someone quotes "our AHT", this tells you which
-- number they have and whether it is the one that belongs in a cost model.
--
-- Param: {{project_id}}
--
-- Row A is the cost-correct one (see aht_cost_per_task.sql).
-- Row F reproduces the platform standard_dashboard AHT tile
-- (platform/queries/throughput/avg_handling_time.sql), which keys on
-- from_state IN ('edit_task','redo_task'). Projects without those states --
-- chartography among them -- yield 0 tasks and the tile is silently blank.
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
rev AS (
  SELECT DISTINCT ON (ptr.payable_time_entry_id)
         ptr.id, ptr.total_seconds, ptr.started_at, pte.user_id, pte.timer_session_id
  FROM payable_time_revisions ptr
  JOIN payable_time_entries pte ON pte.id = ptr.payable_time_entry_id
  WHERE ptr.project_id = {{project_id}}
  ORDER BY ptr.payable_time_entry_id, ptr.revision_number DESC
),
seg AS (
  SELECT s.total_seconds::numeric AS secs,
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
tot AS (
  SELECT sum(secs) / 3600.0                    AS payable_h,
         sum(secs + nonpayable_secs) / 3600.0  AS clocked_h,
         sum(usd)                              AS accrued_usd
  FROM seg
),
timer_tot AS (
  -- Raw timer basis, exactly as the pre-existing AHT queries use it.
  -- NOTE active_project_id is self-reported "what am I working on now"; ground
  -- truth flags it as unreliable for contributors who move between projects.
  SELECT sum(ts.total_seconds) / 3600.0 AS timer_h
  FROM timer_sessions ts
  WHERE ts.active_project_id = {{project_id}}
    AND ts.user_id NOT IN (SELECT id FROM internal)
),
tp AS (
  SELECT t.id AS task_id FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = {{project_id}}
),
ev AS (
  SELECT tst.* FROM tsip_state_transitions tst
  JOIN tp ON tp.task_id = tst.task_id
  WHERE tst.from_state IS DISTINCT FROM tst.to_state
),
den AS (
  SELECT
    (SELECT count(DISTINCT e.task_id) FROM ev e
      JOIN revenue_states rs ON rs.project_id = {{project_id}} AND rs.st = e.to_state) AS ever_delivered,
    (SELECT count(*) FROM (
        SELECT DISTINCT ON (task_id) task_id, to_state FROM ev ORDER BY task_id, created_at DESC
     ) x JOIN revenue_states rs ON rs.project_id = {{project_id}} AND rs.st = x.to_state) AS currently_accepted,
    (SELECT count(DISTINCT task_id) FROM ev WHERE to_state = 'review')                   AS ever_reached_review,
    (SELECT count(DISTINCT task_id) FROM ev
      WHERE event = 'SUBMIT_ANNOTATION' AND from_state LIKE 'annotate%')                 AS ever_submitted,
    (SELECT count(DISTINCT task_id) FROM ev
      WHERE from_state IN ('edit_task','redo_task'))                                     AS advanced_out_of_edit_redo
)
SELECT defn, hours_basis, ROUND(hours::numeric, 0) AS hours,
       denom_basis, denom AS tasks,
       ROUND((hours / NULLIF(denom, 0))::numeric, 2)   AS aht_hours_per_task,
       ROUND((accrued / NULLIF(denom, 0))::numeric, 0) AS cost_per_task_usd
FROM (
  SELECT 'A. CANONICAL cost-grounded' AS defn, 'payable' AS hours_basis, t.payable_h AS hours,
         'first arrival into delivery' AS denom_basis, d.ever_delivered AS denom,
         t.accrued_usd AS accrued FROM tot t, den d
  UNION ALL SELECT 'B. A, acceptance-still-stands', 'payable', t.payable_h,
         'currently in a delivery state', d.currently_accepted, t.accrued_usd FROM tot t, den d
  UNION ALL SELECT 'C. A, but clocked hours', 'clocked (timer_sessions)', tt.timer_h,
         'first arrival into delivery', d.ever_delivered, t.accrued_usd FROM tot t, den d, timer_tot tt
  UNION ALL SELECT 'D. contributor-summary style', 'clocked (timer_sessions)', tt.timer_h,
         'tasks reaching review', d.ever_reached_review, t.accrued_usd FROM tot t, den d, timer_tot tt
  UNION ALL SELECT 'E. touch-time proxy (capacity)', 'payable', t.payable_h,
         'tasks ever submitted', d.ever_submitted, t.accrued_usd FROM tot t, den d
  UNION ALL SELECT 'F. platform standard_dashboard', 'clocked (timer_sessions)', tt.timer_h,
         'advanced out of edit_task/redo_task', d.advanced_out_of_edit_redo, t.accrued_usd
         FROM tot t, den d, timer_tot tt
) z
ORDER BY defn
