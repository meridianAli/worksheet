-- Every task sitting in decomp review right now (tsip_prd, Metabase db id 2).
--
-- Two states carry the name across the platform's pipelines:
--   sheets                            -> 'decomp_review'
--   advanced-workbook-project /
--   legacy-archive-advanced-workbook  -> 'pending_decomp_review'
-- Both are matched here so nothing is missed; archived tasks are flagged, not
-- dropped, because the two legacy projects hold nothing but archived rows.
--
-- entered_at comes from the transition log (last arrival into the state), not
-- tasks.updated_at, which any unrelated write bumps.
WITH q AS (
  SELECT t.id AS task_id, pv.project_id, t.status,
         t.created_at, t.archived_at, t.pooled_at, t.timeout_at,
         t.assigned_user_id, t.task_owner_id
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE t.status IN ('decomp_review', 'pending_decomp_review')
),
entry AS (
  SELECT DISTINCT ON (tst.task_id)
         tst.task_id, tst.created_at AS entered_at, tst.from_state,
         tst.triggered_by, tst.assigned_user_id AS entered_by_user_id
  FROM tsip_state_transitions tst
  JOIN q ON q.task_id = tst.task_id AND q.status = tst.to_state
  ORDER BY tst.task_id, tst.created_at DESC
)
SELECT q.project_id,
       q.status,
       q.task_id,
       e.entered_at,
       ROUND(EXTRACT(EPOCH FROM (now() - e.entered_at)) / 86400.0, 1) AS days_waiting,
       e.from_state AS arrived_from,
       e.triggered_by,
       u.email AS entered_by,
       a.email AS assigned_to,
       q.created_at AS task_created_at,
       (q.archived_at IS NOT NULL) AS archived,
       q.pooled_at
FROM q
LEFT JOIN entry e ON e.task_id = q.task_id
LEFT JOIN tsip_users u ON u.id = e.entered_by_user_id
LEFT JOIN tsip_users a ON a.id = q.assigned_user_id
ORDER BY (q.archived_at IS NOT NULL), e.entered_at
