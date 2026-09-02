-- SOTA gate tab: live sheets tasks waiting in needs_sota_eval, with the
-- signals that predict whether the external SOTA sweep will score them too
-- easy (Foundational / Intermediate) and the bucket once it lands.
--
-- Decomper prior = share of that decomper's SOTA-scored tasks (decomp submitted
-- in the last 60 days) bucketed Foundational or Intermediate.
--
-- Template tags (dashboard filters): stage, decomper, entered_from, entered_to, source_file.
WITH live AS (
  SELECT t.id, t.status, t.created_at, t.updated_at, t.metadata
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets' AND t.archived_at IS NULL
    AND t.status IN ('needs_sota_eval')
),
la AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.metadata AS m, a.messages
  FROM tsip_attempts a JOIN live ON live.id = a.task_id
  ORDER BY a.task_id, a.created_at DESC
),
lo AS (
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
-- decomper of every sheets task decomped in the last 60 days (for the prior)
decomp_all AS (
  SELECT DISTINCT ON (tst.task_id) tst.task_id, tst.triggered_by AS user_id, tst.created_at AS decomp_at
  FROM tsip_state_transitions tst
  JOIN tsip_tasks t ON t.id = tst.task_id
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id AND pv.project_id = 'sheets'
  WHERE tst.event = 'SUBMIT_DECOMP' AND tst.created_at >= now() - interval '60 days'
  ORDER BY tst.task_id, tst.created_at DESC
),
scored AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.metadata->>'sota_bucket' AS bucket
  FROM tsip_attempts a
  JOIN decomp_all d ON d.task_id = a.task_id
  WHERE a.metadata ? 'sota_bucket' AND d.decomp_at >= now() - interval '60 days'
  ORDER BY a.task_id, a.submitted_at DESC NULLS LAST, a.created_at DESC
),
prior AS (
  SELECT d.user_id,
         COUNT(*) AS scored_tasks,
         ROUND(100.0 * COUNT(*) FILTER (WHERE s.bucket IN ('Foundational','Intermediate')) / COUNT(*), 1) AS too_easy_pct
  FROM scored s JOIN decomp_all d ON d.task_id = s.task_id
  GROUP BY 1
),
-- other tasks cut from the same source workbook that already have a bucket
src AS (
  SELECT DISTINCT a.task_id, a.metadata->'uploaded_workbooks'->0->>'fileId' AS src_file_id
  FROM tsip_attempts a JOIN scored sc ON sc.task_id = a.task_id
  WHERE a.metadata ? 'uploaded_workbooks'
),
src_scored AS (
  SELECT DISTINCT s.task_id, s.src_file_id, sc.bucket
  FROM src s JOIN scored sc ON sc.task_id = s.task_id
),
siblings AS (
  SELECT lsrc.task_id,
         COUNT(DISTINCT ss.task_id) AS siblings_scored,
         COUNT(DISTINCT ss.task_id) FILTER (WHERE ss.bucket IN ('Foundational','Intermediate')) AS siblings_too_easy
  FROM (SELECT lo.task_id, lo.m->'uploaded_workbooks'->0->>'fileId' AS src_file_id FROM lo) lsrc
  JOIN src_scored ss ON ss.src_file_id = lsrc.src_file_id AND ss.task_id <> lsrc.task_id
  WHERE lsrc.src_file_id IS NOT NULL
  GROUP BY 1
),
b AS (
  SELECT
    left(live.id::text, 8)                                   AS task,
    live.id                                                  AS task_id,
    live.status,
    'SOTA gate'                                              AS family,
    ROUND(EXTRACT(EPOCH FROM (now() - COALESCE(e.entered_state_at, live.updated_at))) / 86400.0, 1) AS days_waiting,
    COALESCE(e.entered_state_at, live.updated_at) AS entered_state_at,
    COALESCE(e.visits, 0)                                    AS visits,
    du.email                                                 AS decomper_email,
    pr.too_easy_pct                                          AS decomper_too_easy_pct,
    pr.scored_tasks                                          AS decomper_scored_n,
    la.m->>'sota_bucket'                                     AS sota_bucket,
    length(p.prompt_text)                                    AS prompt_chars,
    length(lo.m->>'task_outline')                            AS outline_chars,
    (SELECT count(*) FROM regexp_split_to_table(lo.m->>'task_outline', E'\n') l
       WHERE l ~ '^\s*([-*•]|\d+[.)])\s')                    AS bullets,
    (lo.m->>'decomp_unique_formula_count')::numeric          AS unique_formulas,
    CASE WHEN (lo.m->>'decomp_unique_formula_count')::numeric < 50   THEN '<50'
         WHEN (lo.m->>'decomp_unique_formula_count')::numeric < 150  THEN '50-149'
         WHEN (lo.m->>'decomp_unique_formula_count')::numeric < 300  THEN '150-299'
         WHEN (lo.m->>'decomp_unique_formula_count')::numeric IS NOT NULL THEN '300+' END AS formulas_band,
    CASE WHEN length(lo.m->>'task_outline') < 3000  THEN '<3k'
         WHEN length(lo.m->>'task_outline') < 6000  THEN '3-6k'
         WHEN length(lo.m->>'task_outline') < 10000 THEN '6-10k'
         WHEN lo.m->>'task_outline' IS NOT NULL      THEN '>10k' END AS outline_band,
    COALESCE(sb.siblings_scored, 0)                          AS siblings_scored,
    COALESCE(sb.siblings_too_easy, 0)                        AS siblings_too_easy,
    CASE
      WHEN la.m->>'sota_bucket' = 'Foundational'             THEN 'scored Foundational → cancel'
      WHEN la.m->>'sota_bucket' = 'Intermediate'             THEN 'scored Intermediate → coin flip'
      WHEN la.m->>'sota_bucket' IN ('Challenging','Difficult') THEN 'scored ' || (la.m->>'sota_bucket') || ' → proceed'
      WHEN length(lo.m->>'task_outline') < 3000
        OR (lo.m->>'decomp_unique_formula_count')::numeric < 150 THEN 'likely too easy (thin outline / few formulas)'
      WHEN COALESCE(sb.siblings_too_easy,0) > 0
       AND sb.siblings_too_easy * 2 >= sb.siblings_scored    THEN 'risk: siblings from this file scored too easy'
      WHEN pr.too_easy_pct >= 50                             THEN 'risk: decomper prior ≥ 50 %'
      ELSE 'proceed if scored ≥ Challenging'
    END AS predicted_release,
    COALESCE(lo.m->'uploaded_workbooks'->0->>'fileName', la.m->'uploaded_workbooks'->0->>'fileName', f.input_name) AS source_file,
    ROUND(f.in_bytes  / 1024.0)                              AS input_kb,
    ROUND(f.out_bytes / 1024.0)                              AS output_kb,
    left(live.metadata->>'clonedFrom', 8)                    AS clone_of,
    live.created_at                                          AS task_created_at,
    le.event                                                 AS last_event,
    lu.email                                                 AS last_event_by,
    le.created_at                                            AS last_event_at
  FROM live
  LEFT JOIN entered   e  ON e.task_id  = live.id
  LEFT JOIN la           ON la.task_id = live.id
  LEFT JOIN lo           ON lo.task_id = live.id
  LEFT JOIN prompt    p  ON p.task_id  = live.id
  LEFT JOIN files     f  ON f.task_id  = live.id
  LEFT JOIN siblings  sb ON sb.task_id = live.id
  LEFT JOIN decomper  d  ON d.task_id  = live.id
  LEFT JOIN prior     pr ON pr.user_id = d.user_id
  LEFT JOIN last_ev   le ON le.task_id = live.id
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
