-- Audit trail: every task counted, who it was credited to, when it hit audit.
WITH internal AS (SELECT id FROM tsip_users WHERE lower(split_part(email,'@',2)) IN
   ('meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')),
ptm AS (SELECT user_id FROM tsip_project_members
        WHERE project_id='sheets' AND role::text='prompt_tasker'),
tp AS (SELECT t.id AS task_id FROM tsip_tasks t
       JOIN tsip_project_versions pv ON pv.id=t.project_version_id WHERE pv.project_id='sheets'),
fa AS (SELECT tst.task_id, min(tst.created_at) AS audit_at
       FROM tsip_state_transitions tst JOIN tp ON tp.task_id=tst.task_id
       WHERE tst.to_state='audit' AND tst.from_state IS DISTINCT FROM 'audit' GROUP BY 1
       HAVING (min(tst.created_at) AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date
              BETWEEN '2026-08-01' AND '2026-08-31'),
cred AS (SELECT fa.task_id, fa.audit_at,
           (SELECT e.triggered_by FROM tsip_state_transitions e
             WHERE e.task_id=fa.task_id AND e.from_state IN ('edit_task','redo_task')
               AND e.from_state IS DISTINCT FROM e.to_state AND e.created_at<=fa.audit_at
             ORDER BY e.created_at DESC LIMIT 1) AS user_id
         FROM fa)
SELECT c.task_id::text, COALESCE(u.name,u.email) AS contributor, u.email,
       to_char(c.audit_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York','YYYY-MM-DD HH24:MI') AS audit_at_et,
       (SELECT count(DISTINCT cl.user_id) FROM tsip_task_claims cl WHERE cl.task_id=c.task_id) AS people_who_held_it,
       (SELECT count(*) FROM tsip_state_transitions e WHERE e.task_id=c.task_id
          AND e.to_state='redo_task' AND e.created_at<=c.audit_at) AS redo_rounds
FROM cred c JOIN tsip_users u ON u.id=c.user_id
WHERE c.user_id IN (SELECT user_id FROM ptm) AND c.user_id NOT IN (SELECT id FROM internal)
ORDER BY 2, 4
