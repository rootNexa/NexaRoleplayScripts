-- Phase 7D - Furniture foundation
-- Additive schema for server-authoritative property furniture placement.

CREATE TABLE IF NOT EXISTS property_furniture (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    property_unit_id BIGINT UNSIGNED NOT NULL,
    placed_by_character_id BIGINT UNSIGNED NULL,
    model VARCHAR(64) NOT NULL,
    label VARCHAR(64) NOT NULL,
    position JSON NOT NULL,
    rotation JSON NOT NULL,
    metadata JSON NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_property_furniture_property_unit_id (property_unit_id),
    KEY idx_property_furniture_placed_by_character_id (placed_by_character_id),
    KEY idx_property_furniture_is_active (is_active),
    CONSTRAINT fk_property_furniture_property_unit_id FOREIGN KEY (property_unit_id) REFERENCES property_units (id) ON DELETE CASCADE,
    CONSTRAINT fk_property_furniture_placed_by_character_id FOREIGN KEY (placed_by_character_id) REFERENCES characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name, checksum, executed_at, executed_by, duration_ms)
VALUES ('20260706_1200', 'create_property_furniture', 'manual-phase-7d', NOW(), 'codex', 0)
ON DUPLICATE KEY UPDATE executed_at = VALUES(executed_at);
