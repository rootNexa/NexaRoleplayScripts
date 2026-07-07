CREATE TABLE IF NOT EXISTS illegal_reputation (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id BIGINT UNSIGNED NOT NULL,
    reputation_type VARCHAR(32) NOT NULL,
    reputation_score INT UNSIGNED NOT NULL DEFAULT 0,
    risk_level ENUM('low','medium','high') NOT NULL DEFAULT 'low',
    metadata JSON NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_illegal_reputation_character_type (character_id, reputation_type),
    KEY idx_illegal_reputation_character_id (character_id),
    KEY idx_illegal_reputation_reputation_type (reputation_type),
    KEY idx_illegal_reputation_risk_level (risk_level),
    CONSTRAINT fk_illegal_reputation_character
        FOREIGN KEY (character_id) REFERENCES characters(id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name, checksum, executed_at, executed_by, duration_ms)
VALUES ('20260706_1300', 'create_illegal_core', 'manual-phase-9a', NOW(), 'codex', 0)
ON DUPLICATE KEY UPDATE executed_at = VALUES(executed_at);
