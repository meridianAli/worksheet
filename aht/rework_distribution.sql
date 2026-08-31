-- Redo distribution on tasks that reached audit in the window, + first-pass yield
WITH tp AS (SELECT t.id AS task_id FROM tsip_tasks t
            JOIN tsip_project_versions pv ON pv.id=t.project_version_id WHERE pv.project_id='sheets'),
fa AS (
  SELECT tst.task_id, min(tst.created_at) AS audit_at
  FROM tsip_state_transitions tst JOIN tp ON tp.task_id=tst.task_id
  WHERE tst.to_state='audit' AND tst.from_state IS DISTINCT FROM 'audit' GROUP BY 1
),
fw AS (SELECT * FROM fa WHERE (audit_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/New_York')::date
                              BETWEEN '2026-07-01' AND '2026-08-31'),
r AS (
  SELECT fw.task_id,
         (SELECT count(*) FROM tsip_state_transitions x
           WHERE x.task_id=fw.task_id AND x.to_state='redo_task'
             AND x.from_state IS DISTINCT FROM 'redo_task') AS redos,
         EXTRACT(EPOCH FROM (fw.audit_at - (SELECT min(y.created_at) FROM tsip_state_transitions y
             WHERE y.task_id=fw.task_id AND y.to_state='edit_task')))/86400.0 AS days_edit_to_audit
  FROM fw
)
SELECT CASE WHEN redos=0 THEN '0 redos (first-pass)'
            WHEN redos=1 THEN '1 redo'
            WHEN redos=2 THEN '2 redos'
            WHEN redos BETWEEN 3 AND 4 THEN '3-4 redos'
            WHEN redos BETWEEN 5 AND 9 THEN '5-9 redos'
            ELSE '10+ redos' END AS redo_band,
       count(*) AS tasks,
       ROUND((100.0*count(*)/sum(count(*)) OVER ())::numeric,1) AS pct_tasks,
       sum(redos) AS total_redo_events,
       ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY days_edit_to_audit)::numeric,1) AS median_days_edit_to_audit
FROM r GROUP BY 1
ORDER BY min(redos)
