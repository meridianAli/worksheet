-- Decomp tab: every live sheets task in a decomp-family state, with the
-- columns that decide what to do with it (outline present/quality, agent runs
-- that read nothing, workbook size, recommended action).
--
-- Template tags (dashboard filters): stage, decomper, entered_from, entered_to, source_file.
WITH live AS (
  SELECT t.id, t.status, t.created_at, t.updated_at, t.metadata, t.assigned_user_id
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status IN ('needs_decomp','decomp_complexity_check','generating_outline',
                     'failed_generating_outline','decomp_review')
),
-- latest attempt that carries an outline (the decomp submission)
lo AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.metadata AS m, a.submitted_at
  FROM tsip_attempts a JOIN live ON live.id = a.task_id
  WHERE a.metadata ? 'task_outline'
  ORDER BY a.task_id, a.submitted_at DESC NULLS LAST, a.created_at DESC
),
-- latest attempt with messages: carries the input/output workbook pair the agents read
lm AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.messages, a.metadata AS m
  FROM tsip_attempts a JOIN live ON live.id = a.task_id
  WHERE jsonb_array_length(COALESCE(a.messages, '[]'::jsonb)) > 0
  ORDER BY a.task_id, a.created_at DESC
),
pair AS (
  SELECT lm.task_id,
    (SELECT (ci->'_annotations'->>'fileId')::uuid FROM jsonb_array_elements(lm.messages) msg, jsonb_array_elements(msg->'content') ci
      WHERE ci->'_annotations'->>'field_id' = 'input_workbook' LIMIT 1)  AS in_id,
    (SELECT (ci->'_annotations'->>'fileId')::uuid FROM jsonb_array_elements(lm.messages) msg, jsonb_array_elements(msg->'content') ci
      WHERE ci->'_annotations'->>'field_id' = 'output_workbook' LIMIT 1) AS out_id
  FROM lm
),
files AS (
  SELECT p.task_id, fi.filename AS input_name, fi.size AS in_bytes, fo.size AS out_bytes,
         (fi.content_hash = fo.content_hash) AS identical_pair
  FROM pair p
  LEFT JOIN tsip_files fi ON fi.id = p.in_id
  LEFT JOIN tsip_files fo ON fo.id = p.out_id
),
entered AS (
  SELECT tst.task_id, MAX(tst.created_at) AS entered_state_at, COUNT(*) AS visits
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id AND tst.to_state = live.status
  GROUP BY 1
),
tx AS (
  SELECT tst.task_id,
         COUNT(*) FILTER (WHERE tst.to_state = 'generating_outline') AS outline_generations,
         COUNT(*) FILTER (WHERE tst.event = 'ADMIN_OVERRIDE')       AS admin_overrides
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
runs AS (
  SELECT p.task_id,
         COUNT(*) AS agent_runs,
         COUNT(*) FILTER (WHERE p.input_tokens < 10000) AS empty_context_runs,
         MAX(p.created_at) AS last_run_at
  FROM tsip_model_run_progress p JOIN live ON live.id = p.task_id
  WHERE p.job_type = 'modal_claude_agent'
  GROUP BY 1
),
last_run AS (
  SELECT DISTINCT ON (p.task_id) p.task_id, p.input_tokens, p.output_tokens, p.status
  FROM tsip_model_run_progress p JOIN live ON live.id = p.task_id
  WHERE p.job_type = 'modal_claude_agent'
  ORDER BY p.task_id, p.created_at DESC
),
compass AS (
  SELECT DISTINCT ON (c.task_id) c.task_id, c.template_id, c.error_message, c.created_at
  FROM (SELECT substring(r.workflow_id FROM 9 FOR 36) AS task_id, r.template_id, r.error_message, r.started_at AS created_at
          FROM tsip_data_compass_runs r
         WHERE r.workflow_id LIKE 'compass-%' AND r.failed_count > 0) c
  JOIN live ON live.id::text = c.task_id
  ORDER BY c.task_id, c.created_at DESC
),
claim AS (
  SELECT DISTINCT ON (c.task_id) c.task_id, c.user_id, c.claimed_at, c.expires_at
  FROM tsip_task_claims c JOIN live ON live.id = c.task_id
  WHERE c.status = 'active'
  ORDER BY c.task_id, c.claimed_at DESC
),
outline AS (
  SELECT lo.task_id,
         lo.m->>'task_outline' AS outline_text,
         length(lo.m->>'task_outline') AS outline_chars,
         length(lo.m->>'transition_description') AS transition_chars,
         (SELECT count(*) FROM regexp_split_to_table(lo.m->>'task_outline', E'\n') l
           WHERE l ~ '^\s*([-*•]|\d+[.)])\s') AS bullets,
         (SELECT count(*) FROM regexp_split_to_table(lo.m->>'task_outline', E'\n') l
           WHERE l ~* '(Introduction:|New tab|Modified tabs|\(heavy\)|input_workbook_url|Final output)') AS summary_bullets
  FROM lo
),
b AS (
  SELECT
    left(live.id::text, 8)                                   AS task,
    live.id                                                  AS task_id,
    live.status,
    'Decomp'                                                 AS family,
    ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 86400.0, 1) AS days_in_state,
    COALESCE(e.entered_state_at, live.updated_at) AS entered_state_at,
    COALESCE(e.visits, 0)                                    AS visits,
    du.email                                                 AS decomper_email,
    cu.email                                                 AS claim_holder,
    c.claimed_at, c.expires_at,
    COALESCE(lo.m->'uploaded_workbooks'->0->>'fileName', lm.m->'uploaded_workbooks'->0->>'fileName', f.input_name) AS source_file,
    ROUND(f.in_bytes  / 1024.0)                              AS input_kb,
    ROUND(f.out_bytes / 1024.0)                              AS output_kb,
    (COALESCE(f.in_bytes,0) + COALESCE(f.out_bytes,0)) > 4 * 1024 * 1024 AS over_4mb,
    f.identical_pair,
    (lo.m->>'decomp_unique_formula_count')::numeric          AS unique_formulas,
    left(live.metadata->>'clonedFrom', 8)                    AS clone_of,
    (lo.task_id IS NOT NULL)                                 AS has_outline,
    o.outline_chars, o.bullets, o.summary_bullets, o.transition_chars,
    COALESCE(tx.outline_generations, 0)                      AS outline_generations,
    COALESCE(tx.admin_overrides, 0)                          AS admin_overrides,
    COALESCE(r.agent_runs, 0)                                AS agent_runs,
    COALESCE(r.empty_context_runs, 0)                        AS empty_context_runs,
    lr.input_tokens                                          AS last_run_in_tokens,
    lr.output_tokens                                         AS last_run_out_tokens,
    lr.status                                                AS last_run_status,
    cp.template_id                                           AS last_compass_step,
    left(cp.error_message, 120)                              AS last_compass_error,
    CASE
      WHEN lo.task_id IS NULL AND live.status = 'needs_decomp'      THEN 'not yet decomped'
      WHEN lo.task_id IS NULL AND live.status = 'generating_outline' THEN 'running'
      WHEN lo.task_id IS NULL                                        THEN 'no outline'
      WHEN o.outline_chars < 3000                                    THEN 'thin'
      WHEN o.summary_bullets > 0                                     THEN 'noisy'
      ELSE 'ok'
    END AS outline_quality,
    CASE
      WHEN live.status = 'needs_decomp'                              THEN '—'
      WHEN live.status = 'generating_outline'                        THEN 'wait'
      WHEN live.status = 'failed_generating_outline' AND lo.task_id IS NOT NULL
                                                                     THEN 'OVERRIDE → decomp_review (outline already exists)'
      WHEN lo.task_id IS NULL AND (COALESCE(f.in_bytes,0)+COALESCE(f.out_bytes,0)) > 4*1024*1024
                                                                     THEN 'HOLD · >4 MB workbook, outline agent fails on it'
      WHEN lo.task_id IS NULL AND COALESCE(r.empty_context_runs,0) >= 3
                                                                     THEN 'HOLD · 3+ empty-context runs, escalate'
      WHEN lo.task_id IS NULL                                        THEN 'REGENERATE outline once'
      WHEN o.outline_chars < 3000                                    THEN 'REVIEW · thin outline'
      WHEN o.summary_bullets > 0                                     THEN 'APPROVE · strip ' || o.summary_bullets || ' summary line(s)'
      ELSE 'APPROVE'
    END AS recommended_action,
    live.created_at                                          AS task_created_at,
    le.event                                                 AS last_event,
    lu.email                                                 AS last_event_by,
    le.created_at                                            AS last_event_at
  FROM live
  LEFT JOIN entered  e  ON e.task_id  = live.id
  LEFT JOIN lo          ON lo.task_id = live.id
  LEFT JOIN lm          ON lm.task_id = live.id
  LEFT JOIN outline  o  ON o.task_id  = live.id
  LEFT JOIN files    f  ON f.task_id  = live.id
  LEFT JOIN tx          ON tx.task_id = live.id
  LEFT JOIN runs     r  ON r.task_id  = live.id
  LEFT JOIN last_run lr ON lr.task_id = live.id
  LEFT JOIN compass  cp ON cp.task_id = live.id::text
  LEFT JOIN claim    c  ON c.task_id  = live.id
  LEFT JOIN decomper d  ON d.task_id  = live.id
  LEFT JOIN last_ev  le ON le.task_id = live.id
  LEFT JOIN tsip_users du ON du.id = d.user_id
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
