-- =============================================================================
-- PATCH-BASED (Motley) IDENTIFIABILITY PROBE
--
-- Run this before anyone asks for "the patch-based AHT". It shows, from live
-- data, why that figure cannot be produced -- and will show it becoming
-- producible if the gaps below ever get fixed.
--
-- Patch-based is a TASK VARIETY inside the `sheets` project (its counterpart is
-- "greenfield"). Neither is a project, a pipeline state, or a task field:
--   * `tsip_projects` has no patch/greenfield/motley row.
--   * No sheets pipeline state contains 'patch' (checked all 53 project versions).
--   * `tsip_tasks.metadata` carries no variety marker (0 of 8,057 sheets tasks).
--   * `tsip_task_sets.name` is bare UUIDs for sheets; no variety there either.
--
-- The ONLY machine-readable marker is a legacy backfill of delivery ZIP
-- filenames onto ATTEMPTS:
--     tsip_attempts.metadata -> 'tmp_deliveries'[] ->> 'tmp_delivery_batch'
--     matching 'patchbased'   (e.g. meridian_patchbased_450ct_06.14.26.zip)
-- Note the `tmp_` prefix -- it is explicitly temporary. It exists only for
-- tasks that were DELIVERED, so it can never identify in-flight work, and
-- greenfield was never backfilled into it at all.
--
-- TWO INDEPENDENT BLOCKERS, both shown by the output below:
--
--  (1) ATTRIBUTION. Hours attach to the PROJECT, never to a task or a variety:
--      timer_sessions.active_project_id and payable_time_revisions.project_id
--      are both project-grain, and payable_time_revisions.task_type -- the one
--      column that could carry it -- is 100% NULL on sheets. Patch-based and
--      greenfield ran concurrently with the same contributors, so their hours
--      are commingled and cannot be split even in principle.
--
--  (2) TIME COVERAGE. The marker covers deliveries 2026-02-09..2026-06-15.
--      Sheets payable-hours data effectively begins 2026-07. The numerator and
--      the denominator do not overlap by a single month.
-- =============================================================================
WITH internal AS (
  SELECT id FROM tsip_users
  WHERE lower(split_part(email, '@', 2)) IN (
    'meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')
),
-- ---------- blocker 1: is there ANY variety-grain attribution? ----------
attribution AS (
  SELECT 'payable_time_revisions.task_type populated (sheets)' AS probe,
         count(*) FILTER (WHERE ptr.task_type IS NOT NULL)::text || ' of '
           || count(*)::text || ' rows' AS finding
  FROM payable_time_revisions ptr WHERE ptr.project_id = 'sheets'
  UNION ALL
  SELECT 'tsip_tasks.metadata carries a variety marker (sheets)',
         count(*) FILTER (WHERE t.metadata::text ~* 'patch|greenfield|motley')::text
           || ' of ' || count(*)::text || ' tasks'
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets'
  UNION ALL
  SELECT 'sheets pipeline config mentions a variety',
         count(*) FILTER (WHERE pv.pipeline::text ~* 'patch|greenfield|motley')::text
           || ' of ' || count(*)::text || ' project versions'
  FROM tsip_project_versions pv WHERE pv.project_id = 'sheets'
),
-- ---------- blocker 2: when does each side of the ratio exist? ----------
rev AS (
  SELECT DISTINCT ON (ptr.payable_time_entry_id)
         ptr.id, ptr.total_seconds, ptr.started_at, pte.user_id
  FROM payable_time_revisions ptr
  JOIN payable_time_entries pte ON pte.id = ptr.payable_time_entry_id
  WHERE ptr.project_id = 'sheets'
  ORDER BY ptr.payable_time_entry_id, ptr.revision_number DESC
),
hours_by_month AS (
  SELECT date_trunc('month',
           (s.started_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date)::date AS mon,
         sum(s.total_seconds) / 3600.0 AS payable_h
  FROM rev r
  JOIN payable_time_revision_segments s ON s.revision_id = r.id
  WHERE r.user_id NOT IN (SELECT id FROM internal)
  GROUP BY 1
),
pb_delivered AS (
  SELECT date_trunc('month', d.delivered_on)::date AS mon,
         count(DISTINCT d.task_id) AS pb_tasks_delivered
  FROM (
    SELECT a.task_id,
           (e->>'delivered_on')::date AS delivered_on,
           e->>'tmp_delivery_batch'   AS batch
    FROM tsip_attempts a
    JOIN tsip_tasks t ON t.id = a.task_id
    JOIN tsip_project_versions pv ON pv.id = t.project_version_id,
         jsonb_array_elements(a.metadata -> 'tmp_deliveries') e
    WHERE pv.project_id = 'sheets' AND a.metadata ? 'tmp_deliveries'
  ) d
  WHERE d.batch ~* 'patchbased'
  GROUP BY 1
),
overlap AS (
  SELECT 'OVERLAP: months with BOTH payable hours and patch-based deliveries' AS probe,
         count(*)::text || ' months' AS finding
  FROM hours_by_month h
  JOIN pb_delivered p ON p.mon = h.mon
  WHERE h.payable_h > 100 AND p.pb_tasks_delivered > 0
)
SELECT probe, finding FROM attribution
UNION ALL SELECT probe, finding FROM overlap
UNION ALL
SELECT 'MONTH ' || to_char(COALESCE(h.mon, p.mon), 'YYYY-MM'),
       'payable_h=' || ROUND(COALESCE(h.payable_h, 0)::numeric, 0)::text
         || '  patch_based_delivered=' || COALESCE(p.pb_tasks_delivered, 0)::text
FROM hours_by_month h
FULL OUTER JOIN pb_delivered p ON p.mon = h.mon
ORDER BY 1
