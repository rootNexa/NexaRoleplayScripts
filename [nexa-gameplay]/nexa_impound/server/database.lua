NexaImpoundDatabase = {}

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
    if not db or not db[method] then return nil, { code = NEXA_IMPOUND_ERRORS.databaseError } end
    return db[method](sql, params or {}, { category = category or 'impound.db' })
end

function NexaImpoundDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '113_impound_foundation',
        description = 'Create vehicle impound records.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_vehicle_impounds (
                id INT AUTO_INCREMENT PRIMARY KEY,
                vehicle_id INT NOT NULL,
                impound_type VARCHAR(32) NOT NULL,
                reason VARCHAR(255) NOT NULL,
                status VARCHAR(32) NOT NULL,
                fee_amount BIGINT NOT NULL DEFAULT 0,
                billing_invoice_id INT NULL,
                impounded_by_account_id BIGINT NULL,
                impounded_by_character_id BIGINT NULL,
                released_by_account_id BIGINT NULL,
                released_by_character_id BIGINT NULL,
                release_garage_id VARCHAR(64) NULL,
                impounded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                released_at TIMESTAMP NULL,
                metadata_json LONGTEXT NULL,
                INDEX idx_impound_vehicle (vehicle_id, status)
            )]], {}, { category = 'impound.migration.impounds' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaImpoundDatabase.InsertImpound(i)
    return dbCall('Insert', 'INSERT INTO nexa_vehicle_impounds (vehicle_id, impound_type, reason, status, fee_amount, billing_invoice_id, impounded_by_account_id, impounded_by_character_id, release_garage_id, metadata_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { i.vehicle_id, i.impound_type, i.reason, i.status, i.fee_amount, i.billing_invoice_id, i.impounded_by_account_id, i.impounded_by_character_id, i.release_garage_id, encode(i.metadata) }, 'impound.insert')
end

function NexaImpoundDatabase.GetImpound(id)
    return dbCall('Single', 'SELECT * FROM nexa_vehicle_impounds WHERE id = ? LIMIT 1', { id }, 'impound.get')
end

function NexaImpoundDatabase.ListImpounds(filter)
    filter = type(filter) == 'table' and filter or {}
    if filter.vehicle_id then return dbCall('Query', 'SELECT * FROM nexa_vehicle_impounds WHERE vehicle_id = ? ORDER BY id DESC', { filter.vehicle_id }, 'impound.vehicle') end
    return dbCall('Query', 'SELECT * FROM nexa_vehicle_impounds ORDER BY id DESC LIMIT 200', {}, 'impound.list')
end

function NexaImpoundDatabase.Release(id, actor, releaseGarageId)
    return dbCall('Update', 'UPDATE nexa_vehicle_impounds SET status = ?, released_by_account_id = ?, released_by_character_id = ?, release_garage_id = ?, released_at = CURRENT_TIMESTAMP WHERE id = ?', { NEXA_IMPOUND_STATUS.released, actor.actor_account_id, actor.actor_character_id, releaseGarageId, id }, 'impound.release')
end

function NexaImpoundDatabase.Cancel(id)
    return dbCall('Update', 'UPDATE nexa_vehicle_impounds SET status = ? WHERE id = ?', { NEXA_IMPOUND_STATUS.cancelled, id }, 'impound.cancel')
end

function NexaImpoundDatabase.GetSchema()
    return { migration = '113_impound_foundation', tables = { 'nexa_vehicle_impounds' } }
end
