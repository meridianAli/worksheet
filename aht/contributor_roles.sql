SELECT m.user_id::text, m.role::text AS role, m.stage::text AS stage,
       (u.deactivated_at IS NOT NULL) AS deactivated
FROM tsip_project_members m
JOIN tsip_users u ON u.id=m.user_id
WHERE m.project_id='sheets'
