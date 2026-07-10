NexaGaragesDatabase = {}

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
    if not db or not db[method] then return nil, { code = NEXA_GARAGE_ERRORS.databaseError } end
    return db[method](sql, params or {}, { category = category or 'garages.db' })
end

function NexaGaragesDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '112_garages_foundation',
        description = 'Create vehicle garages and storage audit.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_garages (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(64) UNIQUE NOT NULL,
                label VARCHAR(128) NOT NULL,
                garage_type VARCHAR(32) NOT NULL,
                owner_type VARCHAR(32) NULL,
                owner_id VARCHAR(64) NULL,
                capacity INT NOT NULL DEFAULT 50,
                enabled TINYINT(1) NOT NULL DEFAULT 1,
                location_json LONGTEXT NULL,
                rules_json LONGTEXT NULL,
                metadata_json LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_garage_owner (owner_type, owner_id, enabled)
            )]], {}, { category = 'garages.migration.garages' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_garage_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                garage_id INT NULL,
                vehicle_id INT NULL,
                action VARCHAR(64) NOT NULL,
                actor_account_id BIGINT NULL,
                actor_character_id BIGINT NULL,
                result VARCHAR(32) NOT NULL,
                error_code VARCHAR(64) NULL,
                source_resource VARCHAR(64) NULL,
                correlation_id VARCHAR(128) NULL,
                metadata_json LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )]], {}, { category = 'garages.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaGaragesDatabase.InsertGarage(g)
    return dbCall('Insert', 'INSERT INTO nexa_garages (name, label, garage_type, owner_type, owner_id, capacity, enabled, location_json, rules_json, metadata_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { g.name, g.label, g.garage_type, g.owner_type, g.owner_id, g.capacity, g.enabled and 1 or 0, encode(g.location), encode(g.rules), encode(g.metadata) }, 'garages.garage.insert')
end

function NexaGaragesDatabase.GetGarage(idOrName)
    local id = tonumber(idOrName)
    if id then return dbCall('Single', 'SELECT * FROM nexa_garages WHERE id = ? LIMIT 1', { id }, 'garages.garage.get') end
    return dbCall('Single', 'SELECT * FROM nexa_garages WHERE name = ? LIMIT 1', { tostring(idOrName) }, 'garages.garage.name')
end

function NexaGaragesDatabase.ListGarages()
    return dbCall('Query', 'SELECT * FROM nexa_garages ORDER BY label ASC LIMIT 500', {}, 'garages.garage.list')
end

function NexaGaragesDatabase.ListStored(garageName)
    return dbCall('Query', 'SELECT * FROM nexa_vehicles WHERE garage_id = ? AND status = ? ORDER BY plate ASC', { tostring(garageName), 'stored' }, 'garages.vehicles.stored')
end

function NexaGaragesDatabase.InsertAudit(a)
    return dbCall('Insert', 'INSERT INTO nexa_garage_audit (garage_id, vehicle_id, action, actor_account_id, actor_character_id, result, error_code, source_resource, correlation_id, metadata_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { a.garage_id, a.vehicle_id, a.action, a.actor_account_id, a.actor_character_id, a.result, a.error_code, a.source_resource, a.correlation_id, encode(a.metadata) }, 'garages.audit.insert')
end

function NexaGaragesDatabase.GetSchema()
    return { migration = '112_garages_foundation', tables = { 'nexa_garages', 'nexa_garage_audit' } }
end
