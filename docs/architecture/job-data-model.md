# Job Data Model

Die Foundation nutzt append-only Migrationen:

- `nexa_job_definitions`
- `nexa_job_phases`
- `nexa_job_tasks`
- `nexa_job_sessions`
- `nexa_job_session_members`
- `nexa_job_task_progress`
- `nexa_job_rewards`
- `nexa_job_cooldowns`
- `nexa_job_resource_nodes`
- `nexa_job_production_chains`
- `nexa_job_audit`

Definitionen sind versioniert. Sessions speichern Runtime-State. Progress und Rewards besitzen eigene Tabellen, damit Completion und Auszahlung auditierbar und idempotent bleiben.
