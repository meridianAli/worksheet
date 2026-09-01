-- Is the failure explained by the workbooks rather than the invocation?
--
-- IMPORTANT: the files the outline agent actually reads are the pair carried in
-- tsip_attempts.messages, annotated field_id='input_workbook' / 'output_workbook'.
-- These are NOT metadata->'uploaded_workbooks', which is the source model the
-- decomper started from. Use this pair for any workbook-based analysis.
WITH arr AS (
  SELECT tst.task_id, min(tst.created_at) AS entered_at
  FROM tsip_state_transitions tst
  JOIN tsip_tasks t ON t.id = tst.task_id
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id AND pv.project_id = 'sheets'
  WHERE tst.to_state = 'decomp_review' AND tst.created_at >= now() - interval '21 days'
  GROUP BY 1
),
o AS (
  SELECT arr.task_id, arr.entered_at, bool_or(a.metadata ? 'task_outline') AS has_outline
  FROM arr LEFT JOIN tsip_attempts a ON a.task_id = arr.task_id
  GROUP BY 1, 2
),
pair AS (
  SELECT DISTINCT ON (a.task_id) a.task_id,
    (SELECT c->'_annotations'->>'fileId'
       FROM jsonb_array_elements(a.messages) m, jsonb_array_elements(m->'content') c
      WHERE c->'_annotations'->>'field_id' = 'input_workbook'  LIMIT 1)::uuid AS in_id,
    (SELECT c->'_annotations'->>'fileId'
       FROM jsonb_array_elements(a.messages) m, jsonb_array_elements(m->'content') c
      WHERE c->'_annotations'->>'field_id' = 'output_workbook' LIMIT 1)::uuid AS out_id
  FROM tsip_attempts a JOIN o ON o.task_id = a.task_id
  WHERE jsonb_array_length(a.messages) > 0
  ORDER BY a.task_id, a.created_at DESC
),
sz AS (
  SELECT o.task_id, o.entered_at, o.has_outline,
         fi.id AS in_id, fo.id AS out_id,
         fi.content_hash = fo.content_hash AS identical_content,
         (fi.size + fo.size) / 1024.0 AS pair_kb
  FROM o
  JOIN pair ON pair.task_id = o.task_id
  JOIN tsip_files fi ON fi.id = pair.in_id
  JOIN tsip_files fo ON fo.id = pair.out_id
)
-- (a) are input and output ever the same workbook?  (answer so far: never)
-- (b) does size explain it, or does the 08-26 onset survive holding size fixed?
SELECT CASE WHEN pair_kb < 1000 THEN 'small <1MB'
            WHEN pair_kb < 4000 THEN 'mid 1-4MB'
            ELSE 'big 4MB+' END AS band,
       CASE WHEN entered_at < '2026-08-26' THEN 'before 08-26' ELSE 'from 08-26' END AS era,
       count(*) AS tasks,
       count(*) FILTER (WHERE identical_content) AS input_equals_output,
       count(*) FILTER (WHERE NOT has_outline) AS failed,
       ROUND(100.0 * count(*) FILTER (WHERE NOT has_outline) / count(*), 1) AS pct_failed
FROM sz
GROUP BY 1, 2
ORDER BY 1, 2;
