-- Per-task PAYABLE hours for the credited prompt_tasker, on tasks that first
-- reached audit in August 2026. Payable segments Jul-Aug so pre-August work on
-- an August-completing task is included.
WITH ptm AS (SELECT user_id FROM tsip_project_members
             WHERE project_id='sheets' AND role::text='prompt_tasker'),
internal AS (SELECT id FROM tsip_users WHERE lower(split_part(email,'@',2)) IN
   ('meridian.ai','tsip.ai','op.workada.co','theworkapp.ai','thworkapp.ai',
    'mail-tester.com','srv1.mail-tester.com','ia-tester.com')),
rev AS (SELECT DISTINCT ON (ptr.payable_time_entry_id) ptr.id, pte.user_id
        FROM payable_time_revisions ptr
        JOIN payable_time_entries pte ON pte.id=ptr.payable_time_entry_id
        WHERE ptr.project_id='sheets' AND ptr.started_at >= '2026-06-25'
        ORDER BY ptr.payable_time_entry_id, ptr.revision_number DESC),
seg AS (SELECT s.id AS seg_id, r.user_id, s.started_at, s.ended_at, s.total_seconds
        FROM rev r JOIN payable_time_revision_segments s ON s.revision_id=r.id
        WHERE r.user_id IN (SELECT user_id FROM ptm)
          AND r.user_id NOT IN (SELECT id FROM internal)
          AND s.started_at < '2026-09-01' AND s.ended_at > '2026-06-25'),
cl AS (SELECT c.task_id, c.user_id, c.claimed_at,
              COALESCE(c.last_activity_at, c.closed_at, c.claimed_at) AS ended
       FROM tsip_task_claims c WHERE c.user_id IN (SELECT DISTINCT user_id FROM seg)),
ov AS (SELECT s.seg_id, s.user_id, s.total_seconds AS seg_secs, cl.task_id,
              GREATEST(EXTRACT(EPOCH FROM (LEAST(s.ended_at, cl.ended) - GREATEST(s.started_at, cl.claimed_at))),0) AS ov_secs
       FROM seg s JOIN cl ON cl.user_id = s.user_id
        AND cl.claimed_at < s.ended_at AND cl.ended > s.started_at),
ov2 AS (SELECT seg_id, user_id, task_id, seg_secs, ov_secs,
               sum(ov_secs) OVER (PARTITION BY seg_id) AS seg_ov_total FROM ov),
alloc AS (SELECT task_id, user_id, sum(ov_secs * LEAST(1.0, seg_secs/NULLIF(seg_ov_total,0))) AS secs
          FROM ov2 GROUP BY 1,2),
tp AS (SELECT t.id AS task_id FROM tsip_tasks t
       JOIN tsip_project_versions pv ON pv.id=t.project_version_id WHERE pv.project_id='sheets'),
fa AS (SELECT tst.task_id, min(tst.created_at) AS audit_at
       FROM tsip_state_transitions tst JOIN tp ON tp.task_id=tst.task_id
       WHERE tst.to_state='audit' AND tst.from_state IS DISTINCT FROM 'audit'
       GROUP BY 1
       HAVING (min(tst.created_at) AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date
              BETWEEN '2026-08-01' AND '2026-08-31'),
cred AS (SELECT fa.task_id, fa.audit_at,
           (SELECT e.triggered_by FROM tsip_state_transitions e
             WHERE e.task_id=fa.task_id AND e.from_state IN ('edit_task','redo_task')
               AND e.from_state IS DISTINCT FROM e.to_state AND e.created_at <= fa.audit_at
             ORDER BY e.created_at DESC LIMIT 1) AS user_id
         FROM fa)
SELECT c.task_id::text, COALESCE(u.name,u.email) AS contributor, u.email,
       ROUND(COALESCE(a.secs,0)::numeric/3600.0, 4) AS payable_h_on_task
FROM cred c
JOIN tsip_project_members m ON m.user_id=c.user_id AND m.project_id='sheets' AND m.role::text='prompt_tasker'
JOIN tsip_users u ON u.id=c.user_id
LEFT JOIN alloc a ON a.task_id=c.task_id AND a.user_id=c.user_id
