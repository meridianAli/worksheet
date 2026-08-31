-- What the sheets labour figure EXCLUDES: seeds, AI compute, internal ops.
WITH internal AS (
  SELECT id FROM tsip_users WHERE lower(split_part(email,'@',2)) IN
   ('meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')
)
-- 1. seed / artifact acquisition, paid in a DIFFERENT project (piece-rate, not hourly)
SELECT '1 seed acquisition (sheets-artifact-collection)' AS bucket,
       e.source_type AS detail,
       ROUND((sum(CASE WHEN e.direction='debit' THEN -e.amount_cents ELSE e.amount_cents END)/100.0)::numeric,0) AS usd,
       count(*) AS rows_
FROM contributor_earnings e
WHERE e.project_id='sheets-artifact-collection'
  AND e.earned_date >= '2026-07-01' AND e.earned_date <= '2026-08-31'
GROUP BY 2
UNION ALL
-- 2. internal / ops labour booked to sheets (excluded by the internal filter)
SELECT '2 internal ops labour on sheets', 'hours (@meridian.ai etc)',
       ROUND((sum(CASE WHEN e.direction='debit' THEN -e.amount_cents ELSE e.amount_cents END)/100.0)::numeric,0),
       count(*)
FROM contributor_earnings e
WHERE e.project_id='sheets' AND e.user_id IN (SELECT id FROM internal)
  AND e.earned_date >= '2026-07-01' AND e.earned_date <= '2026-08-31'
UNION ALL
-- 3. non-hourly earnings on sheets itself (bonuses, piece rate) -- also outside the hourly figure
SELECT '3 non-hourly earnings on sheets', e.source_type,
       ROUND((sum(CASE WHEN e.direction='debit' THEN -e.amount_cents ELSE e.amount_cents END)/100.0)::numeric,0),
       count(*)
FROM contributor_earnings e
WHERE e.project_id='sheets' AND e.source_type <> 'hours'
  AND e.earned_date >= '2026-07-01' AND e.earned_date <= '2026-08-31'
GROUP BY 2
ORDER BY 1,3 DESC
