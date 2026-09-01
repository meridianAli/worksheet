-- Manifest of everything needed to audit the outline failures offline.
--
-- Metabase can produce this list but CANNOT fetch the files: it is a SQL layer
-- over Postgres, and the workbooks live in blob storage. Run this, export CSV,
-- then feed it to fetch_workbooks.py from somewhere with API credentials.
--
-- One row per task that entered decomp_review in the window, with:
--   * whether the outline generation succeeded (the label to compare against)
--   * the input/output workbook file ids + blob paths + sizes
--   * the data-compass blob holding the agent's raw response (task_outline_og)
WITH arr AS (
  SELECT tst.task_id, min(tst.created_at) AS entered_at
  FROM tsip_state_transitions tst
  JOIN tsip_tasks t ON t.id = tst.task_id
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id AND pv.project_id = 'sheets'
  WHERE tst.to_state = 'decomp_review'
    AND tst.created_at >= now() - interval '14 days'
  GROUP BY 1
),
o AS (
  SELECT arr.task_id, arr.entered_at,
         bool_or(a.metadata ? 'task_outline') AS has_outline
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
  FROM tsip_attempts a
  WHERE jsonb_array_length(a.messages) > 0
    AND a.task_id IN (SELECT task_id FROM arr)
  ORDER BY a.task_id, a.created_at DESC
),
agent AS (
  SELECT DISTINCT ON (p.task_id) p.task_id, p.input_tokens, p.output_tokens,
         p.parent_workflow_id
  FROM tsip_model_run_progress p
  WHERE p.job_type = 'modal_claude_agent' AND p.input_tokens IS NOT NULL
    AND p.task_id IN (SELECT task_id FROM arr)
  ORDER BY p.task_id, p.created_at DESC
)
SELECT o.task_id,
       o.entered_at,
       o.has_outline,
       agent.input_tokens,
       agent.output_tokens,
       (agent.input_tokens < 10000) AS empty_context,
       fi.id   AS input_file_id,
       fi.size AS input_bytes,
       fi.blob_path AS input_blob_path,
       fo.id   AS output_file_id,
       fo.size AS output_bytes,
       fo.blob_path AS output_blob_path,
       r.output_data->>'blobPath' AS agent_output_blob_path
FROM o
LEFT JOIN pair  ON pair.task_id = o.task_id
LEFT JOIN agent ON agent.task_id = o.task_id
LEFT JOIN tsip_files fi ON fi.id = pair.in_id
LEFT JOIN tsip_files fo ON fo.id = pair.out_id
LEFT JOIN tsip_data_compass_runs r
       ON r.workflow_id = agent.parent_workflow_id AND r.action_type = 'modal-claude-agent'
WHERE fi.id IS NOT NULL AND fo.id IS NOT NULL
ORDER BY o.has_outline, o.entered_at DESC
