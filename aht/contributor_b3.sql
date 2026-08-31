SELECT u.id::text AS user_id, COALESCE(u.name,u.email) AS contributor,
       COALESCE(m.role::text,'(none)') AS role, COALESCE(m.stage::text,'(none)') AS stage,
       (u.deactivated_at IS NOT NULL) AS deactivated
FROM tsip_users u
LEFT JOIN LATERAL (
  SELECT mm.role, mm.stage FROM tsip_project_members mm
  WHERE mm.project_id='sheets' AND mm.user_id=u.id
  ORDER BY mm.created_at DESC LIMIT 1) m ON true
WHERE COALESCE(LOWER(u.email),'') NOT LIKE '%@meridian.ai'
  AND u.id IN (
    SELECT pte.user_id FROM payable_time_entries pte
    JOIN payable_time_revisions ptr ON ptr.payable_time_entry_id=pte.id
    WHERE ptr.project_id='sheets' AND ptr.started_at>='2026-06-28'
  )
