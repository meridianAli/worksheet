-- Delivery & Terminal tab: live sheets tasks in audit, delivery and terminal
-- states (~6k rows). Kept lean: no agent-run or compass joins.
--
-- Template tags (dashboard filters): stage, decomper, entered_from, entered_to, source_file.
WITH live AS (
  SELECT t.id, t.status, t.created_at, t.updated_at, t.metadata
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status IN ('audit','delivery_holding','delivery_ready','complete','cancelled')
),
mm AS (
  SELECT x.task_id, jsonb_object_agg(x.key, x.value) AS m
  FROM (SELECT DISTINCT ON (a.task_id, kv.key) a.task_id, kv.key, kv.value
          FROM tsip_attempts a JOIN live ON live.id = a.task_id, jsonb_each(a.metadata) kv
         WHERE kv.key IN ('uploaded_workbooks','decomp_unique_formula_count','sota_bucket','contributor_complexity',
                          'computed_complexity','task_designation','opus_max_reward','gemini_avg_reward',
                          'gemini_max_reward','number_of_opus_runs','workbook_diff','tmp_deliveries')
         ORDER BY a.task_id, kv.key, a.created_at DESC) x
  GROUP BY 1
),
srcf AS (
  SELECT mm.task_id, f.filename, f.size
  FROM mm LEFT JOIN tsip_files f ON f.id::text = mm.m->'uploaded_workbooks'->0->>'fileId'
),
entered AS (
  SELECT tst.task_id, MAX(tst.created_at) AS entered_state_at, COUNT(*) AS visits
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id AND tst.to_state = live.status
  GROUP BY 1
),
last_ev AS (
  SELECT DISTINCT ON (tst.task_id) tst.task_id, tst.event, tst.from_state, tst.triggered_by, tst.created_at
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id
  ORDER BY tst.task_id, tst.created_at DESC
),
decomper AS (
  SELECT DISTINCT ON (tst.task_id) tst.task_id, tst.triggered_by AS user_id
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id
  WHERE tst.event = 'SUBMIT_DECOMP'
  ORDER BY tst.task_id, tst.created_at DESC
),
cancel AS (
  SELECT DISTINCT ON (tst.task_id) tst.task_id, tst.from_state, tst.triggered_by, tst.created_at
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id
  WHERE tst.to_state = 'cancelled'
  ORDER BY tst.task_id, tst.created_at DESC
),
fb AS (
  SELECT DISTINCT ON (f.task_id) f.task_id, f.score, f.status
  FROM tsip_task_claude_feedback_runs f JOIN live ON live.id = f.task_id
  ORDER BY f.task_id, f.created_at DESC
),
fnd AS (
  SELECT fi.task_id,
         COUNT(*) FILTER (WHERE NOT fi.resolved AND fi.severity = 'major') AS open_major,
         COUNT(*) FILTER (WHERE NOT fi.resolved AND fi.severity = 'minor') AS open_minor
  FROM tsip_findings fi JOIN live ON live.id = fi.task_id
  GROUP BY 1
),
aud AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.status, a.score, a.auditor_id, a.submitted_at, a.purpose
  FROM tsip_audits a JOIN live ON live.id = a.task_id
  WHERE a.audit_type = 'task_pipeline'
  ORDER BY a.task_id, a.created_at DESC
),
dj AS (
  SELECT DISTINCT ON (d.task_id) d.task_id, d.status, d.task_status_at_delivery, d.completed_at,
         COUNT(*) OVER (PARTITION BY d.task_id) AS delivery_jobs
  FROM tsip_delivery_job_tasks d JOIN live ON live.id = d.task_id
  ORDER BY d.task_id, d.completed_at DESC NULLS LAST
),
claim AS (
  SELECT DISTINCT ON (c.task_id) c.task_id, c.user_id, c.expires_at
  FROM tsip_task_claims c JOIN live ON live.id = c.task_id
  WHERE c.status = 'active'
  ORDER BY c.task_id, c.claimed_at DESC
),
b AS (
  SELECT
    left(live.id::text, 8)                                   AS task,
    live.id                                                  AS task_id,
    live.status,
    'Delivery & Terminal'                                    AS family,
    ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 86400.0, 1) AS days_since,
    COALESCE(e.entered_state_at, live.updated_at) AS entered_state_at,
    COALESCE(e.visits, 0)                                    AS visits,
    du.email                                                 AS decomper_email,
    s.filename                                               AS source_file,
    (mm.m->>'decomp_unique_formula_count')::numeric          AS unique_formulas,
    left(live.metadata->>'clonedFrom', 8)                    AS clone_of,
    mm.m->>'sota_bucket'                                     AS sota_bucket,
    mm.m->>'contributor_complexity'                          AS contributor_complexity,
    mm.m->>'computed_complexity'                             AS computed_complexity,
    mm.m->>'task_designation'                                AS task_designation,
    ad.status                                                AS audit_status,
    ad.score                                                 AS audit_score,
    ad.purpose                                               AS audit_purpose,
    aeu.email                                                AS auditor,
    ad.submitted_at                                          AS audit_submitted_at,
    COALESCE(fnd.open_major, 0)                              AS open_major_findings,
    COALESCE(fnd.open_minor, 0)                              AS open_minor_findings,
    fb.score                                                 AS last_feedback_score,
    fb.status                                                AS last_feedback_status,
    (mm.m->>'opus_max_reward')::numeric                      AS opus_max_reward,
    (mm.m->>'gemini_avg_reward')::numeric                    AS gemini_avg_reward,
    (mm.m->>'gemini_max_reward')::numeric                    AS gemini_max_reward,
    (mm.m->>'number_of_opus_runs')::numeric                  AS opus_runs,
    (mm.m ? 'workbook_diff')                                 AS workbook_diff_present,
    COALESCE(dj.delivery_jobs, 0)                            AS delivery_jobs,
    dj.status                                                AS delivery_status,
    dj.task_status_at_delivery,
    dj.completed_at                                          AS delivered_at,
    cn.from_state                                            AS cancelled_from,
    cnu.email                                                AS cancelled_by,
    cu.email                                                 AS claim_holder,
    c.expires_at                                             AS claim_expires_at,
    live.created_at                                          AS task_created_at,
    le.event                                                 AS last_event,
    lu.email                                                 AS last_event_by,
    le.created_at                                            AS last_event_at
  FROM live
  LEFT JOIN entered  e   ON e.task_id   = live.id
  LEFT JOIN mm           ON mm.task_id  = live.id
  LEFT JOIN srcf     s   ON s.task_id   = live.id
  LEFT JOIN aud      ad  ON ad.task_id  = live.id
  LEFT JOIN fnd          ON fnd.task_id = live.id
  LEFT JOIN fb           ON fb.task_id  = live.id
  LEFT JOIN dj           ON dj.task_id  = live.id
  LEFT JOIN cancel   cn  ON cn.task_id  = live.id
  LEFT JOIN claim    c   ON c.task_id   = live.id
  LEFT JOIN decomper d   ON d.task_id   = live.id
  LEFT JOIN last_ev  le  ON le.task_id  = live.id
  LEFT JOIN tsip_users du  ON du.id  = d.user_id
  LEFT JOIN tsip_users aeu ON aeu.id = ad.auditor_id
  LEFT JOIN tsip_users cnu ON cnu.id = cn.triggered_by
  LEFT JOIN tsip_users cu  ON cu.id  = c.user_id
  LEFT JOIN tsip_users lu  ON lu.id  = le.triggered_by
)
SELECT * FROM b
WHERE 1 = 1
  [[AND b.status = {{stage}}]]
  [[AND b.decomper_email = {{decomper}}]]
  [[AND b.entered_state_at >= {{entered_from}}]]
  [[AND b.entered_state_at <= {{entered_to}}]]
  [[AND b.source_file ILIKE '%' || {{source_file}} || '%']]
ORDER BY b.entered_state_at DESC
