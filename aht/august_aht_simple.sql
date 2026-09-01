-- AHT = August payable hours / August tasks into audit. No modelling.
WITH internal AS (SELECT id FROM tsip_users WHERE lower(split_part(email,'@',2)) IN
   ('meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')),
ptm AS (SELECT user_id FROM tsip_project_members
        WHERE project_id='sheets' AND role::text='prompt_tasker'),
-- (A) HOURS: what we are accountable for paying, August, per person
rev AS (SELECT DISTINCT ON (ptr.payable_time_entry_id) ptr.id, ptr.started_at, pte.user_id
        FROM payable_time_revisions ptr
        JOIN payable_time_entries pte ON pte.id=ptr.payable_time_entry_id
        WHERE ptr.project_id='sheets' AND ptr.started_at >= '2026-07-28'
        ORDER BY ptr.payable_time_entry_id, ptr.revision_number DESC),
seg AS (SELECT r.user_id, s.total_seconds::numeric AS secs, r.started_at,
               (s.started_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date AS day
        FROM rev r JOIN payable_time_revision_segments s ON s.revision_id=r.id
        WHERE r.user_id IN (SELECT user_id FROM ptm)
          AND r.user_id NOT IN (SELECT id FROM internal)),
hrs AS (SELECT user_id,
               sum(secs)/3600.0 AS payable_h,
               count(DISTINCT day) AS active_days,
               sum(secs/3600.0 * COALESCE((SELECT cr.rate_cents_per_hour FROM contributor_rates cr
                  WHERE cr.project_id='sheets' AND (cr.user_id=seg.user_id OR cr.user_id IS NULL)
                    AND cr.effective_from<=seg.started_at
                    AND (cr.effective_to IS NULL OR cr.effective_to>seg.started_at)
                  ORDER BY (cr.user_id IS NOT NULL) DESC, cr.effective_from DESC LIMIT 1),0))/100.0 AS cost
        FROM seg WHERE day BETWEEN '2026-08-01' AND '2026-08-31' GROUP BY 1),
-- (B) TASKS: unique tasks first entering audit in August
tp AS (SELECT t.id AS task_id FROM tsip_tasks t
       JOIN tsip_project_versions pv ON pv.id=t.project_version_id WHERE pv.project_id='sheets'),
fa AS (SELECT tst.task_id, min(tst.created_at) AS audit_at
       FROM tsip_state_transitions tst JOIN tp ON tp.task_id=tst.task_id
       WHERE tst.to_state='audit' AND tst.from_state IS DISTINCT FROM 'audit' GROUP BY 1
       HAVING (min(tst.created_at) AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date
              BETWEEN '2026-08-01' AND '2026-08-31'),
-- B1: credited = whoever last handed it out of edit/redo before audit
cred AS (SELECT fa.task_id,
           (SELECT e.triggered_by FROM tsip_state_transitions e
             WHERE e.task_id=fa.task_id AND e.from_state IN ('edit_task','redo_task')
               AND e.from_state IS DISTINCT FROM e.to_state AND e.created_at<=fa.audit_at
             ORDER BY e.created_at DESC LIMIT 1) AS user_id
         FROM fa),
credn AS (SELECT user_id, count(*) AS tasks_credited FROM cred
          WHERE user_id IN (SELECT user_id FROM ptm) AND user_id NOT IN (SELECT id FROM internal)
          GROUP BY 1),
-- B2: influenced = anyone who ever held the task
infl AS (SELECT c.user_id, count(DISTINCT c.task_id) AS tasks_influenced
         FROM tsip_task_claims c JOIN fa ON fa.task_id=c.task_id
         WHERE c.user_id IN (SELECT user_id FROM ptm) AND c.user_id NOT IN (SELECT id FROM internal)
         GROUP BY 1)
SELECT COALESCE(u.name,u.email) AS contributor, u.email,
       ROUND(h.payable_h,2) AS payable_hours,
       ROUND(h.cost,2)      AS cost_usd,
       h.active_days,
       COALESCE(cn.tasks_credited,0)   AS tasks_credited,
       COALESCE(i.tasks_influenced,0)  AS tasks_influenced
FROM hrs h JOIN tsip_users u ON u.id=h.user_id
LEFT JOIN credn cn ON cn.user_id=h.user_id
LEFT JOIN infl  i  ON i.user_id =h.user_id
ORDER BY 3 DESC
