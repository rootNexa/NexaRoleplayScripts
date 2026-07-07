-- Canonical schema entrypoint through Phase 4E.
-- Apply migrations in database/migrations/ in lexical order.
SOURCE database/migrations/20260705_1200_create_phase_3_schema.sql;
SOURCE database/migrations/20260705_1300_complete_core_database_tables.sql;
SOURCE database/migrations/20260705_1400_add_vehicle_key_expiry_index.sql;
SOURCE database/migrations/20260705_1500_create_vehicle_fines.sql;
SOURCE database/migrations/20260706_1300_create_illegal_core.sql;
