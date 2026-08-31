-- per-contributor hours & cost, sheets, Jul 1 - Aug 31
WITH internal AS (
  SELECT id FROM tsip_users WHERE lower(split_part(email,'@',2)) IN
   ('meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')
),
rev AS (
  SELECT DISTINCT ON (ptr.payable_time_entry_id)
         ptr.id, ptr.total_seconds, ptr.started_at, pte.user_id, pte.timer_session_id
  FROM payable_time_revisions ptr
  JOIN payable_time_entries pte ON pte.id=ptr.payable_time_entry_id
  WHERE ptr.project_id='sheets' AND ptr.started_at >= '2026-06-28'
  ORDER BY ptr.payable_time_entry_id, ptr.revision_number DESC
),
seg AS (
  SELECT (s.started_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date AS day,
         r.user_id, r.started_at,
         s.total_seconds::numeric AS secs,
         GREATEST(COALESCE(ses.total_seconds,r.total_seconds)-r.total_seconds,0)::numeric
           *(s.total_seconds::numeric/NULLIF(r.total_seconds,0)) AS nonpay
  FROM rev r
  JOIN payable_time_revision_segments s ON s.revision_id=r.id
  LEFT JOIN timer_sessions ses ON ses.id=r.timer_session_id
  WHERE r.user_id NOT IN (SELECT id FROM internal)
),
rated AS (
  SELECT g.*, COALESCE((
    SELECT cr.rate_cents_per_hour FROM contributor_rates cr
    WHERE cr.project_id='sheets' AND (cr.user_id=g.user_id OR cr.user_id IS NULL)
      AND cr.effective_from<=g.started_at
      AND (cr.effective_to IS NULL OR cr.effective_to>g.started_at)
    ORDER BY (cr.user_id IS NOT NULL) DESC, cr.effective_from DESC LIMIT 1),0) AS rate_cents
  FROM seg g
  WHERE g.day BETWEEN '2026-07-01' AND '2026-08-31'
)
SELECT user_id::text,
       ROUND((sum(secs)/3600.0)::numeric,2)  AS payable_h,
       ROUND((sum(nonpay)/3600.0)::numeric,2) AS break_idle_h,
       ROUND((sum(secs/3600.0*rate_cents)/100.0)::numeric,2) AS cost_usd,
       count(DISTINCT day) AS active_days,
       ROUND((max(rate_cents)/100.0)::numeric,0) AS rate_usd_h
FROM rated GROUP BY 1
