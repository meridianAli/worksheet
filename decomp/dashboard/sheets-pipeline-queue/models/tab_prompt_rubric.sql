-- Prompt & Rubric tab: live sheets tasks in the prompt / rubric generation
-- states. These states turn over in minutes to hours, so time is in minutes.
--
-- Template tags (dashboard filters): stage, decomper, entered_from, entered_to, source_file.
WITH live AS (
  SELECT t.id, t.status, t.created_at, t.updated_at, t.metadata
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status IN ('generating_prompt','failed_generating_prompt','generating_rubric',
                     'failed_generating_rubric','regenerating_rubric')
),
la AS (  -- latest attempt: carries the generated prompt in messages once it exists
  SELECT DISTINCT ON (a.task_id) a.task_id, a.metadata AS m, a.messages
  FROM tsip_attempts a JOIN live ON live.id = a.task_id
  ORDER BY a.task_id, a.created_at DESC
),
lo AS (  -- latest attempt with the decomp outline
  SELECT DISTINCT ON (a.task_id) a.task_id, a.metadata AS m
  FROM tsip_attempts a JOIN live ON live.id = a.task_id
  WHERE a.metadata ? 'task_outline'
  ORDER BY a.task_id, a.submitted_at DESC NULLS LAST, a.created_at DESC
),
prompt AS (
  SELECT la.task_id,
         (SELECT ci->>'text' FROM jsonb_array_elements(la.messages) msg, jsonb_array_elements(msg->'content') ci
           WHERE ci->'_annotations'->>'field_id' = 'prompt' LIMIT 1) AS prompt_text
  FROM la
),
pair AS (
  SELECT la.task_id,
    (SELECT (ci->'_annotations'->>'fileId')::uuid FROM jsonb_array_elements(la.messages) msg, jsonb_array_elements(msg->'content') ci
      WHERE ci->'_annotations'->>'field_id' = 'input_workbook' LIMIT 1)  AS in_id,
    (SELECT (ci->'_annotations'->>'fileId')::uuid FROM jsonb_array_elements(la.messages) msg, jsonb_array_elements(msg->'content') ci
      WHERE ci->'_annotations'->>'field_id' = 'output_workbook' LIMIT 1) AS out_id
  FROM la
),
files AS (
  SELECT p.task_id, fi.filename AS input_name, fi.size AS in_bytes, fo.size AS out_bytes
  FROM pair p LEFT JOIN tsip_files fi ON fi.id = p.in_id LEFT JOIN tsip_files fo ON fo.id = p.out_id
),
entered AS (
  SELECT tst.task_id, MAX(tst.created_at) AS entered_state_at, COUNT(*) AS visits
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id AND tst.to_state = live.status
  GROUP BY 1
),
tx AS (
  SELECT tst.task_id,
         COUNT(*) FILTER (WHERE tst.to_state = 'generating_prompt')                            AS prompt_tries,
         COUNT(*) FILTER (WHERE tst.event IN ('INITIAL_RUBRIC_GENERATED','RUBRIC_REGENERATED')) AS rubric_generations,
         COUNT(*) FILTER (WHERE tst.to_state = 'regenerating_rubric')                          AS regen_loops,
         COUNT(*) FILTER (WHERE tst.event = 'ADMIN_OVERRIDE')                                  AS admin_overrides,
         COUNT(*) FILTER (WHERE tst.event IN ('PROMPT_GENERATION_FAILED','INITIAL_RUBRIC_GENERATION_FAILED')) AS generation_failures
  FROM tsip_state_transitions tst JOIN live ON live.id = tst.task_id
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
fb AS (
  SELECT DISTINCT ON (f.task_id) f.task_id, f.score, f.status, f.created_at
  FROM tsip_task_claude_feedback_runs f JOIN live ON live.id = f.task_id
  ORDER BY f.task_id, f.created_at DESC
),
fbn AS (
  SELECT f.task_id, COUNT(*) AS feedback_runs
  FROM tsip_task_claude_feedback_runs f JOIN live ON live.id = f.task_id GROUP BY 1
),
compass AS (
  SELECT DISTINCT ON (c.task_id) c.task_id, c.template_id, c.action_type, c.error_message, c.started_at
  FROM (SELECT substring(r.workflow_id FROM 9 FOR 36) AS task_id, r.template_id, r.action_type, r.error_message, r.started_at
          FROM tsip_data_compass_runs r
         WHERE r.workflow_id LIKE 'compass-%' AND r.failed_count > 0) c
  JOIN live ON live.id::text = c.task_id
  ORDER BY c.task_id, c.started_at DESC
),
b AS (
  SELECT
    left(live.id::text, 8)                                   AS task,
    live.id                                                  AS task_id,
    live.status,
    'Prompt & Rubric'                                        AS family,
    ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 60.0)         AS minutes_in_state,
    ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 86400.0, 1)   AS days_in_state,
    COALESCE(e.entered_state_at, live.updated_at) AS entered_state_at,
    COALESCE(e.visits, 0)                                    AS visits,
    du.email                                                 AS decomper_email,
    COALESCE(lo.m->'uploaded_workbooks'->0->>'fileName', la.m->'uploaded_workbooks'->0->>'fileName', f.input_name) AS source_file,
    ROUND(f.in_bytes  / 1024.0)                              AS input_kb,
    ROUND(f.out_bytes / 1024.0)                              AS output_kb,
    (lo.m->>'decomp_unique_formula_count')::numeric          AS unique_formulas,
    length(lo.m->>'task_outline')                            AS outline_chars,
    left(live.metadata->>'clonedFrom', 8)                    AS clone_of,
    (p.prompt_text IS NOT NULL)                              AS prompt_present,
    length(p.prompt_text)                                    AS prompt_chars,
    COALESCE(tx.prompt_tries, 0)                             AS prompt_tries,
    COALESCE(tx.rubric_generations, 0)                       AS rubric_generations,
    COALESCE(tx.regen_loops, 0)                              AS regen_loops,
    COALESCE(tx.generation_failures, 0)                      AS generation_failures,
    COALESCE(tx.admin_overrides, 0)                          AS retries_by_override,
    fb.score                                                 AS last_feedback_score,
    fb.status                                                AS last_feedback_status,
    fb.created_at                                            AS last_feedback_at,
    COALESCE(fbn.feedback_runs, 0)                           AS feedback_runs,
    cp.template_id                                           AS last_compass_step,
    cp.action_type                                           AS last_compass_action,
    left(cp.error_message, 120)                              AS last_compass_error,
    cp.started_at                                            AS last_compass_error_at,
    live.created_at                                          AS task_created_at,
    le.event                                                 AS last_event,
    lu.email                                                 AS last_event_by,
    le.created_at                                            AS last_event_at
  FROM live
  LEFT JOIN entered  e   ON e.task_id   = live.id
  LEFT JOIN la           ON la.task_id  = live.id
  LEFT JOIN lo           ON lo.task_id  = live.id
  LEFT JOIN prompt   p   ON p.task_id   = live.id
  LEFT JOIN files    f   ON f.task_id   = live.id
  LEFT JOIN tx           ON tx.task_id  = live.id
  LEFT JOIN fb           ON fb.task_id  = live.id
  LEFT JOIN fbn          ON fbn.task_id = live.id
  LEFT JOIN compass  cp  ON cp.task_id  = live.id::text
  LEFT JOIN decomper d   ON d.task_id   = live.id
  LEFT JOIN last_ev  le  ON le.task_id  = live.id
  LEFT JOIN tsip_users du ON du.id = d.user_id
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
