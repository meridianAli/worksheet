-- per-contributor stage advances (windowed), sheets
SELECT tst.triggered_by::text AS user_id,
       count(DISTINCT tst.task_id) FILTER (WHERE tst.from_state='needs_decomp')  AS adv_decomp,
       count(DISTINCT tst.task_id) FILTER (WHERE tst.from_state='decomp_review') AS adv_decomp_review,
       count(DISTINCT tst.task_id) FILTER (WHERE tst.from_state='edit_task')     AS adv_edit,
       count(DISTINCT tst.task_id) FILTER (WHERE tst.from_state='redo_task')     AS adv_redo,
       count(*) FILTER (WHERE tst.to_state='task_review')                        AS submissions
FROM tsip_state_transitions tst
JOIN tsip_tasks t ON t.id=tst.task_id
JOIN tsip_project_versions pv ON pv.id=t.project_version_id
WHERE pv.project_id='sheets'
  AND tst.from_state IS DISTINCT FROM tst.to_state
  AND tst.triggered_by IS NOT NULL
  AND tst.created_at >= '2026-07-01' AND tst.created_at < '2026-09-02'
GROUP BY 1
