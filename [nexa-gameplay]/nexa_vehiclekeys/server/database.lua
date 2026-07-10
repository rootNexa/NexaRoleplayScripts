NexaVehicleKeysDatabase = {}

local function coreDatabase()
    if GetResourceState('nexa-core') ~= 'started' then return nil end
    local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end)
    return ok and core and core.Database or nil
end

local function encode(value)
    local ok, encoded = pcall(json.encode, value or {})
    return ok and encoded or '{}'
end

local function dbCall(method, sql, params, category)
    local db = coreDatabase()
    if not db or not db[method] then return nil, { code = NEXA_VEHICLEKEY_ERRORS.databaseError } end
    return db[method](sql, params or {}, { category = category or 'vehiclekeys.db' })
end

function NexaVehicleKeysDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '111_vehiclekeys_foundation',
        description = 'Create vehicle key grants and access state.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_vehicle_keys (
                id INT AUTO_INCREMENT PRIMARY KEY,
                vehicle_id INT NOT NULL,
                holder_type VARCHAR(32) NOT NULL,
                holder_id VARCHAR(64) NOT NULL,
                access_level VARCHAR(32) NOT NULL,
                issued_by_account_id BIGINT NULL,
                issued_by_character_id BIGINT NULL,
                expires_at TIMESTAMP NULL,
                revoked_at TIMESTAMP NULL,
                metadata_json LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY uq_vehicle_key_holder (vehicle_id, holder_type, holder_id, access_level),
                INDEX idx_vehicle_key_holder (holder_type, holder_id, revoked_at)
            )]], {}, { category = 'vehiclekeys.migration.keys' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_vehicle_access_state (
                vehicle_id INT PRIMARY KEY,
                locked TINYINT(1) NOT NULL DEFAULT 1,
                engine_enabled TINYINT(1) NOT NULL DEFAULT 0,
                alarm_active TINYINT(1) NOT NULL DEFAULT 0,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )]], {}, { category = 'vehiclekeys.migration.access' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaVehicleKeysDatabase.GetKey(vehicleId, holderType, holderId)
    return dbCall('Single', 'SELECT * FROM nexa_vehicle_keys WHERE vehicle_id = ? AND holder_type = ? AND holder_id = ? AND revoked_at IS NULL LIMIT 1', { vehicleId, holderType, tostring(holderId) }, 'vehiclekeys.key.get')
end

function NexaVehicleKeysDatabase.ListKeys(vehicleId)
    return dbCall('Query', 'SELECT * FROM nexa_vehicle_keys WHERE vehicle_id = ? AND revoked_at IS NULL ORDER BY id ASC', { vehicleId }, 'vehiclekeys.key.list')
end

function NexaVehicleKeysDatabase.ListHolderKeys(holderType, holderId)
    return dbCall('Query', 'SELECT * FROM nexa_vehicle_keys WHERE holder_type = ? AND holder_id = ? AND revoked_at IS NULL ORDER BY id DESC', { holderType, tostring(holderId) }, 'vehiclekeys.key.holder')
end

function NexaVehicleKeysDatabase.InsertKey(k)
    return dbCall('Insert', 'INSERT INTO nexa_vehicle_keys (vehicle_id, holder_type, holder_id, access_level, issued_by_account_id, issued_by_character_id, expires_at, metadata_json) VALUES (?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?), ?)', { k.vehicle_id, k.holder_type, tostring(k.holder_id), k.access_level, k.issued_by_account_id, k.issued_by_character_id, k.expires_at, encode(k.metadata) }, 'vehiclekeys.key.insert')
end

function NexaVehicleKeysDatabase.RevokeKey(id)
    return dbCall('Update', 'UPDATE nexa_vehicle_keys SET revoked_at = CURRENT_TIMESTAMP WHERE id = ?', { id }, 'vehiclekeys.key.revoke')
end

function NexaVehicleKeysDatabase.SetLockState(vehicleId, locked, engineEnabled, alarmActive)
    return dbCall('Update', 'INSERT INTO nexa_vehicle_access_state (vehicle_id, locked, engine_enabled, alarm_active) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE locked = VALUES(locked), engine_enabled = VALUES(engine_enabled), alarm_active = VALUES(alarm_active)', { vehicleId, locked and 1 or 0, engineEnabled and 1 or 0, alarmActive and 1 or 0 }, 'vehiclekeys.access.upsert')
end

function NexaVehicleKeysDatabase.GetLockState(vehicleId)
    return dbCall('Single', 'SELECT * FROM nexa_vehicle_access_state WHERE vehicle_id = ? LIMIT 1', { vehicleId }, 'vehiclekeys.access.get')
end

function NexaVehicleKeysDatabase.GetSchema()
    return { migration = '111_vehiclekeys_foundation', tables = { 'nexa_vehicle_keys', 'nexa_vehicle_access_state' } }
end
