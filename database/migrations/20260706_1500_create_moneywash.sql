CREATE TABLE IF NOT EXISTS moneywash_transactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    transaction_number VARCHAR(32) NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    station_id VARCHAR(64) NOT NULL,
    dirty_item_name VARCHAR(64) NOT NULL,
    dirty_amount BIGINT NOT NULL,
    clean_amount BIGINT NOT NULL,
    fee_amount BIGINT NOT NULL,
    rate_percent INT UNSIGNED NOT NULL,
    status ENUM('completed','failed') NOT NULL DEFAULT 'completed',
    ledger_id BIGINT UNSIGNED NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_moneywash_transactions_number (transaction_number),
    KEY idx_moneywash_transactions_character_id (character_id),
    KEY idx_moneywash_transactions_station_id (station_id),
    KEY idx_moneywash_transactions_ledger_id (ledger_id),
    KEY idx_moneywash_transactions_created_at (created_at),
    CONSTRAINT fk_moneywash_transactions_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_moneywash_transactions_ledger_id FOREIGN KEY (ledger_id) REFERENCES economy_ledger (id) ON DELETE SET NULL,
    CONSTRAINT chk_moneywash_transactions_dirty_amount CHECK (dirty_amount > 0),
    CONSTRAINT chk_moneywash_transactions_clean_amount CHECK (clean_amount > 0),
    CONSTRAINT chk_moneywash_transactions_fee_amount CHECK (fee_amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name, checksum, executed_at, executed_by, duration_ms)
VALUES ('20260706_1500', 'create_moneywash', 'manual-phase-9d', NOW(), 'codex', 0)
ON DUPLICATE KEY UPDATE executed_at = VALUES(executed_at);
