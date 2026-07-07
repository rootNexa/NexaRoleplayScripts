CREATE TABLE IF NOT EXISTS chopshop_orders (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    order_number VARCHAR(32) NOT NULL,
    character_id BIGINT UNSIGNED NOT NULL,
    order_type ENUM('dismantle','sale') NOT NULL,
    vehicle_id BIGINT UNSIGNED NULL,
    item_name VARCHAR(64) NULL,
    amount INT UNSIGNED NOT NULL DEFAULT 1,
    price BIGINT NOT NULL DEFAULT 0,
    status ENUM('completed','failed','cancelled') NOT NULL DEFAULT 'completed',
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_chopshop_orders_order_number (order_number),
    KEY idx_chopshop_orders_character_id (character_id),
    KEY idx_chopshop_orders_vehicle_id (vehicle_id),
    KEY idx_chopshop_orders_order_type (order_type),
    KEY idx_chopshop_orders_status (status),
    KEY idx_chopshop_orders_created_at (created_at),
    CONSTRAINT fk_chopshop_orders_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_chopshop_orders_vehicle_id FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE SET NULL,
    CONSTRAINT chk_chopshop_orders_amount CHECK (amount > 0),
    CONSTRAINT chk_chopshop_orders_price CHECK (price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name, checksum, executed_at, executed_by, duration_ms)
VALUES ('20260706_1600', 'create_chopshop', 'manual-phase-9e', NOW(), 'codex', 0)
ON DUPLICATE KEY UPDATE executed_at = VALUES(executed_at);
