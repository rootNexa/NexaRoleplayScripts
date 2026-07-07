-- Nexa Roleplay Phase 6E impound support.
-- Adds the documented vehicle_fines table for impound fees.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS vehicle_fines (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_id BIGINT UNSIGNED NOT NULL,
    character_id BIGINT UNSIGNED NULL,
    fine_type ENUM('impound') NOT NULL DEFAULT 'impound',
    amount BIGINT NOT NULL,
    status ENUM('open','paid','waived','cancelled') NOT NULL DEFAULT 'open',
    reason VARCHAR(128) NOT NULL,
    created_by_character_id BIGINT UNSIGNED NULL,
    ledger_id BIGINT UNSIGNED NULL,
    metadata JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at DATETIME NULL,
    PRIMARY KEY (id),
    KEY idx_vehicle_fines_vehicle_status (vehicle_id, status),
    KEY idx_vehicle_fines_character_status (character_id, status),
    KEY idx_vehicle_fines_created_at (created_at),
    CONSTRAINT fk_vehicle_fines_vehicle_id FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE,
    CONSTRAINT fk_vehicle_fines_character_id FOREIGN KEY (character_id) REFERENCES characters (id) ON DELETE SET NULL,
    CONSTRAINT fk_vehicle_fines_created_by_character_id FOREIGN KEY (created_by_character_id) REFERENCES characters (id) ON DELETE SET NULL,
    CONSTRAINT fk_vehicle_fines_ledger_id FOREIGN KEY (ledger_id) REFERENCES economy_ledger (id) ON DELETE SET NULL,
    CONSTRAINT chk_vehicle_fines_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
