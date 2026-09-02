-- All sheets tasks currently in needs_sota_eval, with when they entered the
-- state (latest transition into it) and how long they have been waiting.
-- Metabase database id 2 (tsip_prd). Timestamps are naive UTC.
WITH tp AS (
  SELECT t.id, t.status, t.created_at, t.updated_at, t.creator_id, t.task_owner_id,
         t.assigned_user_id, t.pool_priority, t.archived_at, pv.version, t.metadata
  FROM tsip_tasks t
  JOIN tsip_project_versions pv ON pv.id = t.project_version_id
  WHERE pv.project_id = 'sheets' AND t.status = 'needs_sota_eval'
),
entered AS (
  SELECT DISTINCT ON (task_id) task_id, created_at AS entered_at, from_state, event, triggered_by
  FROM tsip_state_transitions
  WHERE to_state = 'needs_sota_eval' AND from_state IS DISTINCT FROM 'needs_sota_eval'
  ORDER BY task_id, created_at DESC
),
prior_visits AS (
  SELECT task_id, count(*) AS times_entered
  FROM tsip_state_transitions
  WHERE to_state = 'needs_sota_eval' AND from_state IS DISTINCT FROM 'needs_sota_eval'
  GROUP BY task_id
)
SELECT tp.id AS task_id,
       tp.status,
       tp.created_at              AS task_created_at,
       e.entered_at               AS entered_needs_sota_eval_at,
       ROUND(EXTRACT(EPOCH FROM (now() - e.entered_at))/3600.0, 1) AS hours_in_state,
       e.from_state, e.event,
       pv_prior.times_entered,
       tp.version                 AS project_version,
       tp.pool_priority,
       cu.email                   AS creator_email,
       ou.email                   AS task_owner_email,
       tp.metadata->>'clonedFrom'          AS cloned_from_task_id,
       tp.metadata->>'clonedFromProjectId' AS cloned_from_project_id
FROM tp
LEFT JOIN entered e          ON e.task_id = tp.id
LEFT JOIN prior_visits pv_prior ON pv_prior.task_id = tp.id
LEFT JOIN tsip_users cu      ON cu.id = tp.creator_id
LEFT JOIN tsip_users ou      ON ou.id = tp.task_owner_id
ORDER BY e.entered_at;
