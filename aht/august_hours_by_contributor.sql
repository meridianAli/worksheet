-- Every strict prompt_tasker with August payable hours, and their August cost
WITH internal AS (
  SELECT id FROM tsip_users WHERE lower(split_part(email,'@',2)) IN
   ('meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')),
pt AS (SELECT user_id FROM tsip_project_members
       WHERE project_id='sheets' AND role::text='prompt_tasker'),
rev AS (
  SELECT DISTINCT ON (ptr.payable_time_entry_id)
         ptr.id, ptr.total_seconds, ptr.started_at, pte.user_id
  FROM payable_time_revisions ptr
  JOIN payable_time_entries pte ON pte.id=ptr.payable_time_entry_id
  WHERE ptr.project_id='sheets' AND ptr.started_at >= '2026-07-28'
  ORDER BY ptr.payable_time_entry_id, ptr.revision_number DESC),
seg AS (
  SELECT (s.started_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date AS day,
         r.user_id, s.total_seconds::numeric AS secs, r.started_at
  FROM rev r JOIN payable_time_revision_segments s ON s.revision_id=r.id
  WHERE r.user_id IN (SELECT user_id FROM pt) AND r.user_id NOT IN (SELECT id FROM internal))
SELECT seg.user_id::text, COALESCE(u.name,u.email) AS contributor,
       ROUND((sum(secs)/3600.0)::numeric,2) AS aug_payable_h,
       count(DISTINCT day) AS aug_active_days,
       ROUND((sum(secs/3600.0 * COALESCE((
         SELECT cr.rate_cents_per_hour FROM contributor_rates cr
         WHERE cr.project_id='sheets' AND (cr.user_id=seg.user_id OR cr.user_id IS NULL)
           AND cr.effective_from<=seg.started_at
           AND (cr.effective_to IS NULL OR cr.effective_to>seg.started_at)
         ORDER BY (cr.user_id IS NOT NULL) DESC, cr.effective_from DESC LIMIT 1),0))/100.0)::numeric,2) AS aug_cost
FROM seg JOIN tsip_users u ON u.id=seg.user_id
WHERE day BETWEEN '2026-08-01' AND '2026-08-31'
GROUP BY 1,2
