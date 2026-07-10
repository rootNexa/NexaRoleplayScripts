NexaRobberiesDatabase = {}

local function coreDatabase()
    if GetResourceState('nexa-core') ~= 'started' then return nil end
    local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end)
    return ok and core and core.Database or nil
end

local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_ROBBERY_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'robberies.db' }) end

function NexaRobberiesDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '151_robberies_foundation',
        description = 'Create robbery locations phases loot points loot claims and audit.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_robbery_locations (
                id INT AUTO_INCREMENT PRIMARY KEY,
                robbery_key VARCHAR(64) UNIQUE NOT NULL,
                label VARCHAR(128) NOT NULL,
                robbery_type VARCHAR(32) NOT NULL,
                status VARCHAR(32) NOT NULL,
                crime_definition_key VARCHAR(64) NULL,
                position LONGTEXT NULL,
                alarm_policy LONGTEXT NULL,
                reset_policy LONGTEXT NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'robberies.migration.locations' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_robbery_phases (
                id INT AUTO_INCREMENT PRIMARY KEY,
                robbery_location_id INT NOT NULL,
                phase_key VARCHAR(64) NOT NULL,
                phase_type VARCHAR(32) NOT NULL,
                position INT NOT NULL,
                challenge_policy LONGTEXT NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'robberies.migration.phases' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_robbery_loot_points (
                id INT AUTO_INCREMENT PRIMARY KEY,
                robbery_location_id INT NOT NULL,
                loot_key VARCHAR(64) NOT NULL,
                loot_type VARCHAR(32) NOT NULL,
                loot_policy LONGTEXT NULL,
                status VARCHAR(32) NOT NULL DEFAULT 'active',
                metadata LONGTEXT NULL
            )]], {}, { category = 'robberies.migration.loot_points' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_robbery_loot_claims (
                id INT AUTO_INCREMENT PRIMARY KEY,
                session_id INT NOT NULL,
                loot_point_id INT NOT NULL,
                character_id BIGINT NOT NULL,
                status VARCHAR(32) NOT NULL,
                idempotency_key VARCHAR(128) UNIQUE NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'robberies.migration.loot_claims' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_robbery_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                robbery_location_id INT NULL,
                session_id INT NULL,
                action VARCHAR(64) NOT NULL,
                actor_character_id BIGINT NULL,
                reason VARCHAR(255) NULL,
                result VARCHAR(32) NOT NULL,
                error_code VARCHAR(64) NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'robberies.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaRobberiesDatabase.InsertLocation(l) return dbCall('Insert', 'INSERT INTO nexa_robbery_locations (robbery_key, label, robbery_type, status, crime_definition_key, position, alarm_policy, reset_policy, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { l.robbery_key, l.label, l.robbery_type, l.status, l.crime_definition_key, encode(l.position), encode(l.alarm_policy), encode(l.reset_policy), encode(l.metadata) }, 'robberies.location.insert') end
function NexaRobberiesDatabase.GetLocation(idOrKey) local id = tonumber(idOrKey); if id then return dbCall('Single', 'SELECT * FROM nexa_robbery_locations WHERE id = ? LIMIT 1', { id }, 'robberies.location.get') end; return dbCall('Single', 'SELECT * FROM nexa_robbery_locations WHERE robbery_key = ? LIMIT 1', { tostring(idOrKey) }, 'robberies.location.key') end
function NexaRobberiesDatabase.ListLocations(filters) filters = filters or {}; local sql = 'SELECT * FROM nexa_robbery_locations WHERE 1=1'; local params = {}; if filters.robbery_type then sql = sql .. ' AND robbery_type = ?'; params[#params + 1] = filters.robbery_type end; return dbCall('Query', sql .. ' ORDER BY id DESC LIMIT 500', params, 'robberies.location.list') end
function NexaRobberiesDatabase.InsertLootClaim(c) return dbCall('Insert', 'INSERT INTO nexa_robbery_loot_claims (session_id, loot_point_id, character_id, status, idempotency_key, metadata) VALUES (?, ?, ?, ?, ?, ?)', { c.session_id, c.loot_point_id, c.character_id, c.status, c.idempotency_key, encode(c.metadata) }, 'robberies.loot.claim') end
function NexaRobberiesDatabase.InsertAudit(a) return dbCall('Insert', 'INSERT INTO nexa_robbery_audit (robbery_location_id, session_id, action, actor_character_id, reason, result, error_code, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { a.robbery_location_id, a.session_id, a.action, a.actor_character_id, a.reason, a.result, a.error_code, a.correlation_id, encode(a.metadata) }, 'robberies.audit') end
function NexaRobberiesDatabase.GetSchema() return { migration = '151_robberies_foundation', tables = { 'nexa_robbery_locations', 'nexa_robbery_phases', 'nexa_robbery_loot_points', 'nexa_robbery_loot_claims', 'nexa_robbery_audit' } } end
