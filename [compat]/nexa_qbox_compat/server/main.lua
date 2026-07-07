local RESOURCE = GetCurrentResourceName()

local function logInfo(message)
    print(('[%s] %s'):format(RESOURCE, message))
end

local function logWarn(message)
    print(('[%s] WARNING: %s'):format(RESOURCE, message))
end

local function normalizeIdentifierType(identifier)
    if type(identifier) ~= 'string' then
        return nil
    end

    return identifier:match('^([^:]+):')
end

local function getSourceIdentifiers(source)
    local identifiers = {}
    local count = GetNumPlayerIdentifiers(source)

    for index = 0, count - 1 do
        local identifier = GetPlayerIdentifier(source, index)
        local identifierType = normalizeIdentifierType(identifier)

        if identifierType ~= nil and identifierType ~= 'ip' then
            identifiers[#identifiers + 1] = identifier
        end
    end

    return identifiers
end

local function createCompatibilityStorage()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS nexa_qbox_vehicle_inventory (
            vehicle_id BIGINT UNSIGNED NOT NULL,
            glovebox LONGTEXT NULL,
            trunk LONGTEXT NULL,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (vehicle_id),
            CONSTRAINT fk_nexa_qbox_vehicle_inventory_vehicle_id
                FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query.await([[
        INSERT IGNORE INTO nexa_qbox_vehicle_inventory (vehicle_id)
        SELECT id FROM vehicles WHERE deleted_at IS NULL;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS player_jobs_activity (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(64) NULL,
            job VARCHAR(64) NOT NULL,
            last_checkin INT NOT NULL,
            last_checkout INT NULL DEFAULT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_player_jobs_activity_citizenid_job (citizenid, job),
            KEY idx_player_jobs_activity_last_checkout (last_checkout)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end

local function getDatabaseObjectType(name)
    local row = MySQL.single.await([[
        SELECT TABLE_TYPE AS table_type
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?
        LIMIT 1
    ]], {
        name
    })

    return row and row.table_type or nil
end

local function renameExistingPlayerVehiclesTable()
    local baseName = 'player_vehicles_legacy_qbox'
    local targetName = baseName

    if getDatabaseObjectType(targetName) ~= nil then
        local suffix = 0

        repeat
            suffix += 1
            targetName = ('%s_%s_%s'):format(baseName, os.date('!%Y%m%d%H%M%S'), suffix)
        until getDatabaseObjectType(targetName) == nil
    end

    local renamed, err = pcall(MySQL.query.await, ('RENAME TABLE `player_vehicles` TO `%s`'):format(targetName))

    if not renamed then
        local currentType = getDatabaseObjectType('player_vehicles')

        if currentType == nil or currentType == 'VIEW' then
            logInfo('player_vehicles changed while preparing compatibility; continuing idempotently.')
            return true
        end

        logWarn(('Could not preserve legacy player_vehicles table as %s: %s'):format(targetName, err))
        logWarn('Keeping existing player_vehicles table in place; Nexa compatibility view was not installed to avoid data loss.')
        return false
    end

    logInfo(('Existing player_vehicles table preserved as %s before installing Nexa compatibility view.'):format(targetName))
    return true
end

local function preparePlayerVehiclesCompatibilityView()
    local objectType = getDatabaseObjectType('player_vehicles')

    if objectType == nil then
        return
    end

    if objectType == 'VIEW' then
        return true
    end

    return renameExistingPlayerVehiclesTable()
end

local function createVehicleView()
    if not preparePlayerVehiclesCompatibilityView() then
        return
    end

    local viewSql = [[
        CREATE OR REPLACE VIEW player_vehicles AS
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
                    ) AS rank
                FROM player_identifiers
                WHERE type IN ('license2', 'license')
            ) ranked
            WHERE ranked.rank = 1
        ) pi ON pi.player_id = p.id
        LEFT JOIN vehicle_garage_states vgs ON vgs.vehicle_id = v.id
        WHERE v.deleted_at IS NULL;
    ]]

    local created, err = pcall(MySQL.query.await, viewSql)

    if created then
        return
    end

    local objectType = getDatabaseObjectType('player_vehicles')

    if objectType == 'BASE TABLE' and preparePlayerVehiclesCompatibilityView() then
        created, err = pcall(MySQL.query.await, viewSql)

        if created then
            return
        end
    end

    logWarn(('Could not create or replace player_vehicles compatibility view: %s'):format(err))
end

local function createReadOnlyQboxViews()
    MySQL.query.await('DROP VIEW IF EXISTS playerskins')
    MySQL.query.await([[
        CREATE VIEW playerskins AS
        SELECT
            c.citizenid,
            '{}' AS skin,
            0 AS active
        FROM characters c
        WHERE 1 = 0;
    ]])

    MySQL.query.await('DROP VIEW IF EXISTS player_outfits')
    MySQL.query.await([[
        CREATE VIEW player_outfits AS
        SELECT
            c.citizenid,
            CAST(NULL AS CHAR(64)) AS outfitname,
            '{}' AS skin
        FROM characters c
        WHERE 1 = 0;
    ]])

    MySQL.query.await('DROP VIEW IF EXISTS player_groups')
    MySQL.query.await([[
        CREATE VIEW player_groups AS
        SELECT c.citizenid, 'job' AS type, j.name AS `group`, jg.grade_level AS grade
        FROM character_jobs cj
        INNER JOIN characters c ON c.id = cj.character_id
        INNER JOIN jobs j ON j.id = cj.job_id
        INNER JOIN job_grades jg ON jg.id = cj.grade_id
        WHERE cj.ended_at IS NULL
        UNION ALL
        SELECT c.citizenid, 'gang' AS type, f.name AS `group`, fg.grade_level AS grade
        FROM faction_members fm
        INNER JOIN characters c ON c.id = fm.character_id
        INNER JOIN factions f ON f.id = fm.faction_id
        INNER JOIN faction_grades fg ON fg.id = fm.grade_id
        WHERE fm.left_at IS NULL;
    ]])
end

local function installAdapters()
    createCompatibilityStorage()
    createVehicleView()
    createReadOnlyQboxViews()
    logInfo('Qbox compatibility adapters installed; Nexa remains authoritative.')
end

local function syncVehicleCompatibility()
    return MySQL.insert.await([[
        INSERT IGNORE INTO nexa_qbox_vehicle_inventory (vehicle_id)
        SELECT id FROM vehicles WHERE deleted_at IS NULL;
    ]])
end

local function findPlayerByIdentifiers(identifiers)
    if type(identifiers) ~= 'table' or #identifiers == 0 then
        return nil
    end

    local placeholders = {}
    local values = {}

    for index, identifier in ipairs(identifiers) do
        placeholders[index] = '?'
        values[index] = identifier
    end

    return MySQL.single.await(([[ 
        SELECT p.id
        FROM players p
        INNER JOIN player_identifiers pi ON pi.player_id = p.id
        WHERE pi.value IN (%s)
        LIMIT 1
    ]]):format(table.concat(placeholders, ',')), values)
end

local function checkBanForSource(source)
    local identifiers = getSourceIdentifiers(source)
    local player = findPlayerByIdentifiers(identifiers)

    if player == nil then
        return false, nil
    end

    local ban = MySQL.single.await([[
        SELECT id, reason, expires_at
        FROM bans
        WHERE player_id = ?
          AND is_active = 1
          AND (expires_at IS NULL OR expires_at > NOW())
        ORDER BY created_at DESC
        LIMIT 1
    ]], {
        player.id
    })

    if ban == nil then
        MySQL.update.await('UPDATE players SET is_banned = 0, updated_at = NOW() WHERE id = ? AND is_banned = 1', {
            player.id
        })
        return false, nil
    end

    local message = ('You have been banned from the server:\n%s'):format(ban.reason or 'Ban aktiv')

    if ban.expires_at ~= nil then
        message = ('%s\nBan expires at %s'):format(message, ban.expires_at)
    end

    return true, message
end

CreateThread(function()
    local ok, err = pcall(installAdapters)

    if not ok then
        error(('[%s] Failed to install compatibility adapters: %s'):format(RESOURCE, err), 0)
    end
end)

exports('checkBanForSource', checkBanForSource)
exports('syncVehicleCompatibility', syncVehicleCompatibility)
