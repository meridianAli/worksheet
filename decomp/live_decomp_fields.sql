WITH live AS (
  SELECT t.id AS task_id, t.created_at, t.metadata
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id='sheets' AND t.status='decomp_review' AND t.archived_at IS NULL
),
d AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.id AS attempt_id, a.user_id, a.submitted_at, a.metadata AS m
  FROM tsip_attempts a JOIN live ON live.task_id = a.task_id
  WHERE a.metadata ? 'task_outline'
  ORDER BY a.task_id, a.submitted_at DESC
)
SELECT live.task_id,
       u.email AS decomper,
       d.submitted_at,
       length(d.m->>'task_outline') AS outline_len,
       length(d.m->>'transition_description') AS transition_len,
       d.m->>'contributor_complexity' AS contributor_complexity,
       d.m->>'computed_complexity' AS computed_complexity,
       d.m->>'decomp_unique_formula_count' AS unique_formulas,
       d.m->>'task_designation' AS designation,
       d.m->>'requires_decomp' AS requires_decomp,
       (live.metadata ? 'clonedFrom') AS is_clone,
       (live.metadata ? 'generationFailure') AS generation_failure,
       (d.m ? 'workbook_diff') AS has_workbook_diff,
       jsonb_array_length(COALESCE(d.m->'uploaded_workbooks','[]'::jsonb)) AS n_workbooks,
       d.m->>'task_outline' AS task_outline,
       d.m->>'transition_description' AS transition_description
FROM live
LEFT JOIN d ON d.task_id = live.task_id
LEFT JOIN tsip_users u ON u.id = d.user_id
ORDER BY d.submitted_at
