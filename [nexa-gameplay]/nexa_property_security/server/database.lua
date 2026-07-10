NexaPropertySecurityDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_PROPERTY_SECURITY_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'propertysecurity.db' }) end

function NexaPropertySecurityDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '123_property_security_foundation',
        description = 'Create property security state events and burglary attempts.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_security_state (
                property_id INT PRIMARY KEY,
                alarm_status VARCHAR(32) NOT NULL,
                security_level VARCHAR(32) NOT NULL,
                locked_down TINYINT(1) NOT NULL DEFAULT 0,
                metadata LONGTEXT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )]], {}, { category = 'propertysecurity.migration.state' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_security_events (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NOT NULL,
                event_type VARCHAR(64) NOT NULL,
                actor_character_id BIGINT NULL,
                result VARCHAR(32) NOT NULL,
                security_level VARCHAR(32) NULL,
                alarm_triggered TINYINT(1) NOT NULL DEFAULT 0,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL,
                INDEX idx_property_security_event (property_id, event_type)
            )]], {}, { category = 'propertysecurity.migration.events' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_burglary_attempts (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NOT NULL,
                actor_character_id BIGINT NULL,
                entry_point VARCHAR(64) NULL,
                status VARCHAR(32) NOT NULL,
                result VARCHAR(32) NULL,
                access_expires_at TIMESTAMP NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                resolved_at TIMESTAMP NULL,
                metadata LONGTEXT NULL,
                INDEX idx_property_burglary (property_id, status)
            )]], {}, { category = 'propertysecurity.migration.burglary' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaPropertySecurityDatabase.UpsertState(propertyId, status, level, metadata) return dbCall('Update', 'INSERT INTO nexa_property_security_state (property_id, alarm_status, security_level, metadata) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE alarm_status = VALUES(alarm_status), security_level = VALUES(security_level), metadata = VALUES(metadata)', { propertyId, status, level, encode(metadata) }, 'propertysecurity.state.upsert') end
function NexaPropertySecurityDatabase.GetState(propertyId) return dbCall('Single', 'SELECT * FROM nexa_property_security_state WHERE property_id = ? LIMIT 1', { propertyId }, 'propertysecurity.state.get') end
function NexaPropertySecurityDatabase.InsertEvent(e) return dbCall('Insert', 'INSERT INTO nexa_property_security_events (property_id, event_type, actor_character_id, result, security_level, alarm_triggered, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', { e.property_id, e.event_type, e.actor_character_id, e.result, e.security_level, e.alarm_triggered and 1 or 0, e.correlation_id, encode(e.metadata) }, 'propertysecurity.event.insert') end
function NexaPropertySecurityDatabase.InsertBurglary(b) return dbCall('Insert', 'INSERT INTO nexa_property_burglary_attempts (property_id, actor_character_id, entry_point, status, access_expires_at, metadata) VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), ?)', { b.property_id, b.actor_character_id, b.entry_point, b.status, b.access_expires_at, encode(b.metadata) }, 'propertysecurity.burglary.insert') end
function NexaPropertySecurityDatabase.GetActiveBurglary(propertyId) return dbCall('Single', 'SELECT * FROM nexa_property_burglary_attempts WHERE property_id = ? AND status = ? ORDER BY id DESC LIMIT 1', { propertyId, NEXA_PROPERTY_BURGLARY_STATUS.active }, 'propertysecurity.burglary.active') end
function NexaPropertySecurityDatabase.ResolveBurglary(id, status, result) return dbCall('Update', 'UPDATE nexa_property_burglary_attempts SET status = ?, result = ?, resolved_at = CURRENT_TIMESTAMP WHERE id = ?', { status, result, id }, 'propertysecurity.burglary.resolve') end
function NexaPropertySecurityDatabase.GetSchema() return { migration = '123_property_security_foundation', tables = { 'nexa_property_security_state', 'nexa_property_security_events', 'nexa_property_burglary_attempts' } } end
