-- Calibration tab: live sheets calibration tasks (contributor complexity vs
-- computed complexity, calibration item, subject, claim, graded time).
--
-- Template tags (dashboard filters): stage, decomper, entered_from, entered_to, source_file.
WITH live AS (
  SELECT t.id, t.status, t.created_at, t.updated_at, t.metadata, t.assigned_user_id
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status IN ('calibration_available','calibration_grading','calibration_graded','calibration_manual_review')
),
mm AS (
  SELECT x.task_id, jsonb_object_agg(x.key, x.value) AS m
  FROM (SELECT DISTINCT ON (a.task_id, kv.key) a.task_id, kv.key, kv.value
          FROM tsip_attempts a JOIN live ON live.id = a.task_id, jsonb_each(a.metadata) kv
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
graded AS (
  SELECT tst.task_id, MAX(tst.created_at) AS graded_at
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id
  WHERE tst.to_state = 'calibration_graded'
  GROUP BY 1
),
last_ev AS (
  SELECT DISTINCT ON (tst.task_id) tst.task_id, tst.event, tst.triggered_by, tst.created_at
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id
  ORDER BY tst.task_id, tst.created_at DESC
),
decomper AS (
  SELECT DISTINCT ON (tst.task_id) tst.task_id, tst.triggered_by AS user_id
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id
  WHERE tst.event = 'SUBMIT_DECOMP'
  ORDER BY tst.task_id, tst.created_at DESC
),
item AS (
  SELECT cti.task_id, ci.item_key, cti.subject_user_id
  FROM calibration_task_items cti JOIN live ON live.id = cti.task_id
  LEFT JOIN calibration_items ci ON ci.id = cti.item_id
),
claim AS (
  SELECT DISTINCT ON (c.task_id) c.task_id, c.user_id, c.claimed_at, c.expires_at
  FROM tsip_task_claims c JOIN live ON live.id = c.task_id
  WHERE c.status = 'active'
  ORDER BY c.task_id, c.claimed_at DESC
),
aud AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.status, a.score, a.auditor_id, a.submitted_at, a.purpose
  FROM tsip_audits a JOIN live ON live.id = a.task_id
  WHERE a.audit_type = 'task_pipeline'
  ORDER BY a.task_id, a.created_at DESC
),
b AS (
  SELECT
    left(live.id::text, 8)                                   AS task,
    live.id                                                  AS task_id,
    live.status,
    'Calibration'                                            AS family,
    ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 86400.0, 1) AS days_in_state,
    COALESCE(e.entered_state_at, live.updated_at) AS entered_state_at,
    COALESCE(e.visits, 0)                                    AS visits,
    du.email                                                 AS decomper_email,
    au.email                                                 AS assigned_to,
    cu.email                                                 AS claim_holder,
    c.claimed_at, c.expires_at,
    s.filename                                               AS source_file,
    ROUND(s.size / 1024.0)                                   AS source_kb,
    (mm.m->>'decomp_unique_formula_count')::numeric          AS unique_formulas,
    left(live.metadata->>'clonedFrom', 8)                    AS clone_of,
    mm.m->>'contributor_complexity'                          AS contributor_complexity,
    mm.m->>'computed_complexity'                             AS computed_complexity,
    mm.m->>'requires_decomp'                                 AS requires_decomp,
    mm.m->>'calibration_failed_once'                         AS calibration_failed_once,
    live.metadata->'calibration'                             AS task_calibration_meta,
    i.item_key                                               AS calibration_item,
    su.email                                                 AS subject_user,
    ad.status                                                AS audit_status,
    ad.score                                                 AS audit_score,
    ad.purpose                                               AS audit_purpose,
    g.graded_at,
    live.created_at                                          AS task_created_at,
    le.event                                                 AS last_event,
    lu.email                                                 AS last_event_by,
    le.created_at                                            AS last_event_at
  FROM live
  LEFT JOIN entered  e   ON e.task_id   = live.id
  LEFT JOIN mm           ON mm.task_id  = live.id
  LEFT JOIN srcf     s   ON s.task_id   = live.id
  LEFT JOIN graded   g   ON g.task_id   = live.id
  LEFT JOIN item     i   ON i.task_id   = live.id
  LEFT JOIN claim    c   ON c.task_id   = live.id
  LEFT JOIN aud      ad  ON ad.task_id  = live.id
  LEFT JOIN decomper d   ON d.task_id   = live.id
  LEFT JOIN last_ev  le  ON le.task_id  = live.id
  LEFT JOIN tsip_users du ON du.id = d.user_id
  LEFT JOIN tsip_users au ON au.id = live.assigned_user_id
  LEFT JOIN tsip_users cu ON cu.id = c.user_id
  LEFT JOIN tsip_users su ON su.id = i.subject_user_id
  LEFT JOIN tsip_users lu ON lu.id = le.triggered_by
)
SELECT * FROM b
WHERE 1 = 1
  [[AND b.status = {{stage}}]]
  [[AND b.decomper_email = {{decomper}}]]
  [[AND b.entered_state_at >= {{entered_from}}]]
  [[AND b.entered_state_at <= {{entered_to}}]]
  [[AND b.source_file ILIKE '%' || {{source_file}} || '%']]
ORDER BY b.entered_state_at
