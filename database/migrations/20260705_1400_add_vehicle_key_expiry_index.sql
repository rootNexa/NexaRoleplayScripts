SET @nexa_idx_vehicle_keys_expires_at_exists := (
    SELECT COUNT(1)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE()
        AND table_name = 'vehicle_keys'
        AND index_name = 'idx_vehicle_keys_expires_at'
);

SET @nexa_idx_vehicle_keys_expires_at_sql := IF(
    @nexa_idx_vehicle_keys_expires_at_exists = 0,
    'ALTER TABLE vehicle_keys ADD KEY idx_vehicle_keys_expires_at (expires_at)',
    'SELECT 1'
);

PREPARE nexa_idx_vehicle_keys_expires_at_stmt FROM @nexa_idx_vehicle_keys_expires_at_sql;
EXECUTE nexa_idx_vehicle_keys_expires_at_stmt;
DEALLOCATE PREPARE nexa_idx_vehicle_keys_expires_at_stmt;

INSERT INTO schema_migrations (version, name, checksum, executed_at, executed_by, duration_ms)
VALUES ('20260705_1400', 'add_vehicle_key_expiry_index', 'manual-phase-6b', NOW(), 'codex', 0)
ON DUPLICATE KEY UPDATE executed_at = VALUES(executed_at);
