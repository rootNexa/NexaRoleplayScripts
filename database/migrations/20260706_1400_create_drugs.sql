CREATE TABLE IF NOT EXISTS drug_batches (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    batch_number VARCHAR(32) NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    batch_type ENUM('plant','processed') NOT NULL,
    crop_id VARCHAR(64) NULL,
    recipe_id VARCHAR(64) NULL,
    item_name VARCHAR(64) NOT NULL,
    amount INT UNSIGNED NOT NULL,
    status ENUM('planted','harvested','processed','failed') NOT NULL DEFAULT 'planted',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ready_at DATETIME NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_drug_batches_batch_number (batch_number),
    KEY idx_drug_batches_character_id (character_id),
    KEY idx_drug_batches_status (status),
    KEY idx_drug_batches_created_at (created_at),
    CONSTRAINT fk_drug_batches_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT chk_drug_batches_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS drug_sales (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sale_number VARCHAR(32) NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    buyer_id VARCHAR(64) NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    amount INT UNSIGNED NOT NULL,
    price BIGINT NOT NULL,
    status ENUM('completed','failed') NOT NULL DEFAULT 'completed',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_drug_sales_sale_number (sale_number),
    KEY idx_drug_sales_character_id (character_id),
    KEY idx_drug_sales_buyer_id (buyer_id),
    KEY idx_drug_sales_created_at (created_at),
    CONSTRAINT fk_drug_sales_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT chk_drug_sales_amount CHECK (amount > 0),
    CONSTRAINT chk_drug_sales_price CHECK (price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name, checksum, executed_at, executed_by, duration_ms)
VALUES ('20260706_1400', 'create_drugs', 'manual-phase-9c', NOW(), 'codex', 0)
ON DUPLICATE KEY UPDATE executed_at = VALUES(executed_at);
