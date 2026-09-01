-- 1. what decomp-time features predict the SOTA bucket?
WITH s AS (
  SELECT DISTINCT ON (a.task_id) a.task_id, a.metadata->>'sota_bucket' AS bucket
  FROM tsip_attempts a JOIN tsip_tasks t ON t.id=a.task_id
  JOIN tsip_project_versions pv ON pv.id=t.project_version_id AND pv.project_id='sheets'
  WHERE a.metadata ? 'sota_bucket' AND a.submitted_at >= now()-interval '30 days'
  ORDER BY a.task_id, a.submitted_at DESC),
d AS (
  SELECT DISTINCT ON (s.task_id) s.task_id, s.bucket,
    length(a.metadata->>'task_outline') AS outline_len,
    length(a.metadata->>'transition_description') AS trans_len,
    (a.metadata->>'decomp_unique_formula_count')::numeric AS formulas
  FROM s JOIN tsip_attempts a ON a.task_id=s.task_id AND a.metadata ? 'task_outline'
  ORDER BY s.task_id, a.submitted_at DESC)
SELECT bucket, count(*) n,
  ROUND(percentile_cont(0.1) WITHIN GROUP (ORDER BY formulas)) f_p10,
  ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY formulas)) f_med,
  ROUND(percentile_cont(0.9) WITHIN GROUP (ORDER BY formulas)) f_p90,
  ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY outline_len)) outline_med,
  ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY trans_len)) trans_med,
  count(*) FILTER (WHERE (SELECT metadata ? 'clonedFrom' FROM tsip_tasks WHERE id=d.task_id)) clones
FROM d GROUP BY 1 ORDER BY f_med
