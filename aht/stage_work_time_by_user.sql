-- PER-USER, PER-STAGE work time, done properly: intersect each claim's active
-- window with the states the task ACTUALLY occupied during it.
-- Claim window = [claimed_at, LEAST(last_activity_at, claimed_at + 12h)] -- the
-- 12h cap stops an abandoned/expired claim dominating a stage.
WITH tp AS (
  SELECT t.id AS task_id FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id=t.project_version_id WHERE pv.project_id='sheets'
),
state_iv AS (
  SELECT tst.task_id, tst.to_state AS state, tst.created_at AS s_from,
         COALESCE(LEAD(tst.created_at) OVER (PARTITION BY tst.task_id ORDER BY tst.created_at),
                  '2026-09-02'::timestamp) AS s_to
  FROM tsip_state_transitions tst
  JOIN tp ON tp.task_id=tst.task_id
  WHERE tst.from_state IS DISTINCT FROM tst.to_state
    AND tst.created_at >= '2026-06-01'
),
cl AS (
  SELECT c.task_id, c.user_id, c.claimed_at AS c_from,
         LEAST(COALESCE(c.last_activity_at, c.closed_at, c.claimed_at),
               c.claimed_at + interval '12 hours') AS c_to
  FROM tsip_task_claims c
  JOIN tp ON tp.task_id=c.task_id
  WHERE c.claimed_at >= '2026-07-01' AND c.claimed_at < '2026-09-01'
),
ov AS (
  SELECT cl.user_id, s.state,
         EXTRACT(EPOCH FROM (LEAST(cl.c_to, s.s_to) - GREATEST(cl.c_from, s.s_from)))/3600.0 AS h
  FROM cl
  JOIN state_iv s ON s.task_id = cl.task_id
                 AND s.s_from < cl.c_to
                 AND s.s_to   > cl.c_from
)
SELECT user_id::text, state, ROUND(sum(h)::numeric,3) AS work_h, count(*) AS overlaps
FROM ov WHERE h > 0 GROUP BY 1,2
