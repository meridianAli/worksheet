-- Review & Eval tab: live sheets tasks in the review, rubric-eval, redo and
-- edit states. Columns: evidence a reviewer needs (SOTA bucket, complexities,
-- latest Claude feedback run, open findings, hallucination / beginner review
-- artefacts, redo and review loop counts, who holds the claim).
--
-- Attempt metadata is merged across the task's attempts, latest value per key,
-- because different keys are written by different attempts.
--
-- Template tags (dashboard filters): stage, decomper, entered_from, entered_to, source_file.
WITH live AS (
  SELECT t.id, t.status, t.created_at, t.updated_at, t.metadata, t.assigned_user_id, t.pooled_at, t.timeout_at
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status IN ('review_gate','failed_review_gate','rubric_eval','initial_rubric_eval',
                     'failed_rubric_eval','failed_initial_rubric_eval','task_review','initial_task_review',
                     'failed_task_review','failed_initial_task_review','beginner_task_review',
                     'review_eval_hallucination','redo_task','edit_task','one_off_edit')
),
mm AS (  -- merged attempt metadata: latest value per key
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
tx AS (
  SELECT tst.task_id,
         COUNT(*) FILTER (WHERE tst.to_state = 'redo_task')          AS redo_count,
         COUNT(*) FILTER (WHERE tst.to_state LIKE '%review%')        AS review_loops,
         COUNT(*) FILTER (WHERE tst.event = 'ADMIN_OVERRIDE')        AS admin_overrides
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id
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
fb AS (
  SELECT DISTINCT ON (f.task_id) f.task_id, f.score, f.status, f.created_at
  FROM tsip_task_claude_feedback_runs f JOIN live ON live.id = f.task_id
  ORDER BY f.task_id, f.created_at DESC
),
fbn AS (
  SELECT f.task_id, COUNT(*) AS feedback_runs
  FROM tsip_task_claude_feedback_runs f JOIN live ON live.id = f.task_id GROUP BY 1
),
fnd AS (
  SELECT fi.task_id,
         COUNT(*) FILTER (WHERE NOT fi.resolved AND fi.severity = 'major') AS open_major,
         COUNT(*) FILTER (WHERE NOT fi.resolved AND fi.severity = 'minor') AS open_minor,
         COUNT(*) FILTER (WHERE fi.resolved)                                AS resolved_findings
  FROM tsip_findings fi JOIN live ON live.id = fi.task_id
  GROUP BY 1
),
claim AS (
  SELECT DISTINCT ON (c.task_id) c.task_id, c.user_id, c.claimed_at, c.expires_at, c.task_state_at_claim
  FROM tsip_task_claims c JOIN live ON live.id = c.task_id
  WHERE c.status = 'active'
  ORDER BY c.task_id, c.claimed_at DESC
),
b AS (
  SELECT
    left(live.id::text, 8)                                   AS task,
    live.id                                                  AS task_id,
    live.status,
    'Review & Eval'                                          AS family,
    ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 86400.0, 1) AS days_in_state,
    COALESCE(e.entered_state_at, live.updated_at) AS entered_state_at,
    COALESCE(e.visits, 0)                                    AS visits,
    du.email                                                 AS decomper_email,
    au.email                                                 AS assigned_to,
    cu.email                                                 AS claim_holder,
    c.claimed_at, c.expires_at,
    live.pooled_at, live.timeout_at,
    s.filename                                               AS source_file,
    ROUND(s.size / 1024.0)                                   AS source_kb,
    (mm.m->>'decomp_unique_formula_count')::numeric          AS unique_formulas,
    length(mm.m->>'task_outline')                            AS outline_chars,
    left(live.metadata->>'clonedFrom', 8)                    AS clone_of,
    mm.m->>'sota_bucket'                                     AS sota_bucket,
    mm.m->>'contributor_complexity'                          AS contributor_complexity,
    mm.m->>'computed_complexity'                             AS computed_complexity,
    mm.m->>'task_designation'                                AS task_designation,
    fb.score                                                 AS last_feedback_score,
    fb.status                                                AS last_feedback_status,
    fb.created_at                                            AS last_feedback_at,
    COALESCE(fbn.feedback_runs, 0)                           AS feedback_runs,
    COALESCE(fnd.open_major, 0)                              AS open_major_findings,
    COALESCE(fnd.open_minor, 0)                              AS open_minor_findings,
    COALESCE(fnd.resolved_findings, 0)                       AS resolved_findings,
    (mm.m ? 'eval_hallucination_request')                    AS halluc_request_present,
    (mm.m ? 'eval_hallucination_review')                     AS halluc_review_present,
    (mm.m ? 'beginner_review')                               AS beginner_review_present,
    (mm.m ? 'workbook_diff')                                 AS workbook_diff_present,
    COALESCE(tx.redo_count, 0)                               AS redo_count,
    COALESCE(tx.review_loops, 0)                             AS review_loops,
    COALESCE(tx.admin_overrides, 0)                          AS admin_overrides,
    live.created_at                                          AS task_created_at,
    le.event                                                 AS last_event,
    le.from_state                                            AS came_from,
    lu.email                                                 AS last_event_by,
    le.created_at                                            AS last_event_at
  FROM live
  LEFT JOIN entered  e   ON e.task_id   = live.id
  LEFT JOIN mm           ON mm.task_id  = live.id
  LEFT JOIN srcf     s   ON s.task_id   = live.id
  LEFT JOIN tx           ON tx.task_id  = live.id
  LEFT JOIN fb           ON fb.task_id  = live.id
  LEFT JOIN fbn          ON fbn.task_id = live.id
  LEFT JOIN fnd          ON fnd.task_id = live.id
  LEFT JOIN claim    c   ON c.task_id   = live.id
  LEFT JOIN decomper d   ON d.task_id   = live.id
  LEFT JOIN last_ev  le  ON le.task_id  = live.id
  LEFT JOIN tsip_users du ON du.id = d.user_id
  LEFT JOIN tsip_users au ON au.id = live.assigned_user_id
  LEFT JOIN tsip_users cu ON cu.id = c.user_id
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
