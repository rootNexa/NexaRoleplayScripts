-- Zap/minimal runtime compatibility for ox_inventory/qbx vehicle storage.
-- Nexa remains authoritative for vehicles; this exposes the Qbox-shaped table name expected by ox_inventory.

CREATE TABLE IF NOT EXISTS nexa_qbox_vehicle_inventory (
    vehicle_id BIGINT UNSIGNED NOT NULL,
    glovebox LONGTEXT NULL,
    trunk LONGTEXT NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (vehicle_id),
    CONSTRAINT fk_nexa_qbox_vehicle_inventory_vehicle_id
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO nexa_qbox_vehicle_inventory (vehicle_id)
SELECT id FROM vehicles WHERE deleted_at IS NULL;

DROP VIEW IF EXISTS player_vehicles;

CREATE VIEW player_vehicles AS
SELECT
    vi.vehicle_id AS id,
    pi.value AS license,
    c.citizenid AS citizenid,
    v.model AS vehicle,
    CRC32(v.model) AS hash,
    COALESCE(JSON_EXTRACT(v.metadata, '$.mods'), JSON_OBJECT()) AS mods,
    v.plate AS plate,
    CASE COALESCE(vgs.state, v.status)
        WHEN 'stored' THEN 1
        WHEN 'out' THEN 0
        WHEN 'impounded' THEN 2
        WHEN 'seized' THEN 2
        ELSE 0
    END AS state,
    COALESCE(vgs.garage_name, v.garage_name) AS garage,
    0 AS depotprice,
    NULL AS coords,
    vi.glovebox AS glovebox,
    vi.trunk AS trunk
FROM nexa_qbox_vehicle_inventory vi
INNER JOIN vehicles v ON v.id = vi.vehicle_id
LEFT JOIN characters c ON c.id = v.owner_character_id
LEFT JOIN players p ON p.id = c.player_id
LEFT JOIN (
    SELECT ranked.player_id, ranked.value
    FROM (
        SELECT
            player_id,
            value,
            ROW_NUMBER() OVER (
                PARTITION BY player_id
                ORDER BY CASE type WHEN 'license2' THEN 0 WHEN 'license' THEN 1 ELSE 2 END, id
            ) AS identifier_rank
        FROM player_identifiers
        WHERE type IN ('license2', 'license')
    ) ranked
    WHERE ranked.identifier_rank = 1
) pi ON pi.player_id = p.id
LEFT JOIN vehicle_garage_states vgs ON vgs.vehicle_id = v.id
WHERE v.deleted_at IS NULL;

INSERT INTO schema_migrations (version, name, checksum, executed_at, executed_by, duration_ms)
VALUES ('20260707_1200', 'create_qbox_vehicle_inventory_compat', 'zap-minimal-ox-inventory-compat', NOW(), 'codex', 0)
ON DUPLICATE KEY UPDATE executed_at = VALUES(executed_at);
