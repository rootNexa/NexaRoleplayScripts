NexaCrimeDatabase = {}

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
    if not db or not db[method] then return nil, { code = NEXA_CRIME_ERRORS.databaseError, message = 'Core database unavailable.' } end
    return db[method](sql, params or {}, { category = category or 'crime.db' })
end

function NexaCrimeDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '150_crime_foundation',
        description = 'Create crime profiles definitions sessions cooldowns reputation heat locations and audit.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crime_profiles (
                id INT AUTO_INCREMENT PRIMARY KEY,
                character_id BIGINT NOT NULL UNIQUE,
                reputation INT NOT NULL DEFAULT 0,
                heat INT NOT NULL DEFAULT 0,
                flags LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crime.migration.profiles' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crime_definitions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                crime_key VARCHAR(64) UNIQUE NOT NULL,
                label VARCHAR(128) NOT NULL,
                crime_type VARCHAR(32) NOT NULL,
                status VARCHAR(32) NOT NULL,
                minimum_reputation INT NOT NULL DEFAULT 0,
                maximum_heat INT NOT NULL DEFAULT 100,
                minimum_responders INT NOT NULL DEFAULT 0,
                cooldown_seconds INT NOT NULL DEFAULT 0,
                group_allowed TINYINT(1) NOT NULL DEFAULT 0,
                minimum_group_size INT NOT NULL DEFAULT 1,
                maximum_group_size INT NOT NULL DEFAULT 1,
                required_tools LONGTEXT NULL,
                phase_definition LONGTEXT NULL,
                loot_policy LONGTEXT NULL,
                risk_policy LONGTEXT NULL,
                version INT NOT NULL DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                deleted_at TIMESTAMP NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crime.migration.definitions' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crime_sessions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                crime_definition_id INT NOT NULL,
                leader_character_id BIGINT NOT NULL,
                location_id INT NULL,
                status VARCHAR(32) NOT NULL,
                current_phase VARCHAR(64) NULL,
                alarm_triggered TINYINT(1) NOT NULL DEFAULT 0,
                started_at TIMESTAMP NULL,
                expires_at TIMESTAMP NULL,
                completed_at TIMESTAMP NULL,
                cancelled_at TIMESTAMP NULL,
                failure_reason VARCHAR(255) NULL,
                idempotency_key VARCHAR(128) UNIQUE NULL,
                correlation_id VARCHAR(128) NULL,
                metadata LONGTEXT NULL,
                KEY idx_nexa_crime_sessions_status (status)
            )]], {}, { category = 'crime.migration.sessions' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crime_session_members (
                id INT AUTO_INCREMENT PRIMARY KEY,
                session_id INT NOT NULL,
                character_id BIGINT NOT NULL,
                member_role VARCHAR(32) NOT NULL,
                status VARCHAR(32) NOT NULL,
                joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                left_at TIMESTAMP NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crime.migration.members' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crime_cooldowns (
                id INT AUTO_INCREMENT PRIMARY KEY,
                crime_definition_id INT NOT NULL,
                holder_type VARCHAR(32) NOT NULL,
                holder_id VARCHAR(64) NOT NULL,
                starts_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                expires_at TIMESTAMP NOT NULL,
                reason VARCHAR(255) NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crime.migration.cooldowns' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crime_reputation_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                character_id BIGINT NOT NULL,
                delta INT NOT NULL,
                value_after INT NOT NULL,
                reason VARCHAR(255) NOT NULL,
                actor_character_id BIGINT NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crime.migration.reputation' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crime_heat_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                character_id BIGINT NOT NULL,
                delta INT NOT NULL,
                value_after INT NOT NULL,
                reason VARCHAR(255) NOT NULL,
                actor_character_id BIGINT NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crime.migration.heat' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crime_locations (
                id INT AUTO_INCREMENT PRIMARY KEY,
                location_key VARCHAR(64) UNIQUE NOT NULL,
                label VARCHAR(128) NOT NULL,
                crime_type VARCHAR(32) NOT NULL,
                status VARCHAR(32) NOT NULL,
                position LONGTEXT NULL,
                radius INT NOT NULL DEFAULT 5,
                cooldown_seconds INT NOT NULL DEFAULT 0,
                alarm_policy LONGTEXT NULL,
                access_rules LONGTEXT NULL,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crime.migration.locations' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_crime_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                crime_definition_id INT NULL,
                session_id INT NULL,
                action VARCHAR(64) NOT NULL,
                actor_account_id BIGINT NULL,
                actor_character_id BIGINT NULL,
                before_state LONGTEXT NULL,
                after_state LONGTEXT NULL,
                reason VARCHAR(255) NULL,
                result VARCHAR(32) NOT NULL,
                error_code VARCHAR(64) NULL,
                source_resource VARCHAR(64) NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'crime.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaCrimeDatabase.EnsureProfile(characterId) return dbCall('Insert', 'INSERT INTO nexa_crime_profiles (character_id, flags, metadata) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP', { characterId, encode({}), encode({}) }, 'crime.profile.ensure') end
function NexaCrimeDatabase.GetProfile(characterId) return dbCall('Single', 'SELECT * FROM nexa_crime_profiles WHERE character_id = ? LIMIT 1', { characterId }, 'crime.profile.get') end
function NexaCrimeDatabase.AdjustProfile(characterId, field, value) return dbCall('Update', ('UPDATE nexa_crime_profiles SET %s = ?, updated_at = CURRENT_TIMESTAMP WHERE character_id = ?'):format(field), { value, characterId }, 'crime.profile.adjust') end
function NexaCrimeDatabase.InsertDefinition(d) return dbCall('Insert', 'INSERT INTO nexa_crime_definitions (crime_key, label, crime_type, status, minimum_reputation, maximum_heat, minimum_responders, cooldown_seconds, group_allowed, minimum_group_size, maximum_group_size, required_tools, phase_definition, loot_policy, risk_policy, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { d.crime_key, d.label, d.crime_type, d.status, d.minimum_reputation, d.maximum_heat, d.minimum_responders, d.cooldown_seconds, d.group_allowed and 1 or 0, d.minimum_group_size, d.maximum_group_size, encode(d.required_tools), encode(d.phase_definition), encode(d.loot_policy), encode(d.risk_policy), encode(d.metadata) }, 'crime.definition.insert') end
function NexaCrimeDatabase.GetDefinition(idOrKey) local id = tonumber(idOrKey); if id then return dbCall('Single', 'SELECT * FROM nexa_crime_definitions WHERE id = ? AND deleted_at IS NULL LIMIT 1', { id }, 'crime.definition.get') end; return dbCall('Single', 'SELECT * FROM nexa_crime_definitions WHERE crime_key = ? AND deleted_at IS NULL LIMIT 1', { tostring(idOrKey) }, 'crime.definition.key') end
function NexaCrimeDatabase.ListDefinitions(filters) filters = filters or {}; local sql = 'SELECT * FROM nexa_crime_definitions WHERE deleted_at IS NULL'; local params = {}; if filters.status then sql = sql .. ' AND status = ?'; params[#params + 1] = filters.status end; return dbCall('Query', sql .. ' ORDER BY id DESC LIMIT 500', params, 'crime.definition.list') end
function NexaCrimeDatabase.InsertSession(s) return dbCall('Insert', 'INSERT INTO nexa_crime_sessions (crime_definition_id, leader_character_id, location_id, status, current_phase, alarm_triggered, started_at, expires_at, idempotency_key, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, FROM_UNIXTIME(?), ?, ?, ?)', { s.crime_definition_id, s.leader_character_id, s.location_id, s.status, s.current_phase, s.alarm_triggered and 1 or 0, s.expires_at, s.idempotency_key, s.correlation_id, encode(s.metadata) }, 'crime.session.insert') end
function NexaCrimeDatabase.GetSession(id) return dbCall('Single', 'SELECT * FROM nexa_crime_sessions WHERE id = ? LIMIT 1', { id }, 'crime.session.get') end
function NexaCrimeDatabase.ListActiveSessions() return dbCall('Query', 'SELECT * FROM nexa_crime_sessions WHERE status IN (?, ?, ?) ORDER BY id DESC LIMIT 500', { NEXA_CRIME_SESSION_STATUS.created, NEXA_CRIME_SESSION_STATUS.active, NEXA_CRIME_SESSION_STATUS.alarmed }, 'crime.session.active') end
function NexaCrimeDatabase.SetSessionStatus(id, status, reason) return dbCall('Update', 'UPDATE nexa_crime_sessions SET status = ?, failure_reason = ?, completed_at = CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE completed_at END, cancelled_at = CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE cancelled_at END WHERE id = ?', { status, reason, status, NEXA_CRIME_SESSION_STATUS.completed, status, NEXA_CRIME_SESSION_STATUS.cancelled, id }, 'crime.session.status') end
function NexaCrimeDatabase.InsertMember(m) return dbCall('Insert', 'INSERT INTO nexa_crime_session_members (session_id, character_id, member_role, status, metadata) VALUES (?, ?, ?, ?, ?)', { m.session_id, m.character_id, m.member_role, m.status, encode(m.metadata) }, 'crime.member.insert') end
function NexaCrimeDatabase.InsertLocation(l) return dbCall('Insert', 'INSERT INTO nexa_crime_locations (location_key, label, crime_type, status, position, radius, cooldown_seconds, alarm_policy, access_rules, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { l.location_key, l.label, l.crime_type, l.status, encode(l.position), l.radius, l.cooldown_seconds, encode(l.alarm_policy), encode(l.access_rules), encode(l.metadata) }, 'crime.location.insert') end
function NexaCrimeDatabase.GetLocation(idOrKey) local id = tonumber(idOrKey); if id then return dbCall('Single', 'SELECT * FROM nexa_crime_locations WHERE id = ? LIMIT 1', { id }, 'crime.location.get') end; return dbCall('Single', 'SELECT * FROM nexa_crime_locations WHERE location_key = ? LIMIT 1', { tostring(idOrKey) }, 'crime.location.key') end
function NexaCrimeDatabase.ListLocations(filters) filters = filters or {}; local sql = 'SELECT * FROM nexa_crime_locations WHERE 1=1'; local params = {}; if filters.crime_type then sql = sql .. ' AND crime_type = ?'; params[#params + 1] = filters.crime_type end; return dbCall('Query', sql .. ' ORDER BY id DESC LIMIT 500', params, 'crime.location.list') end
function NexaCrimeDatabase.InsertReputationHistory(h) return dbCall('Insert', 'INSERT INTO nexa_crime_reputation_history (character_id, delta, value_after, reason, actor_character_id, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)', { h.character_id, h.delta, h.value_after, h.reason, h.actor_character_id, h.correlation_id, encode(h.metadata) }, 'crime.reputation.history') end
function NexaCrimeDatabase.InsertHeatHistory(h) return dbCall('Insert', 'INSERT INTO nexa_crime_heat_history (character_id, delta, value_after, reason, actor_character_id, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)', { h.character_id, h.delta, h.value_after, h.reason, h.actor_character_id, h.correlation_id, encode(h.metadata) }, 'crime.heat.history') end
function NexaCrimeDatabase.InsertAudit(a) return dbCall('Insert', 'INSERT INTO nexa_crime_audit (crime_definition_id, session_id, action, actor_account_id, actor_character_id, before_state, after_state, reason, result, error_code, source_resource, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { a.crime_definition_id, a.session_id, a.action, a.actor_account_id, a.actor_character_id, a.before_state and encode(a.before_state) or nil, a.after_state and encode(a.after_state) or nil, a.reason, a.result, a.error_code, a.source_resource, a.correlation_id, encode(a.metadata) }, 'crime.audit') end
function NexaCrimeDatabase.GetSchema() return { migration = '150_crime_foundation', tables = { 'nexa_crime_profiles', 'nexa_crime_definitions', 'nexa_crime_sessions', 'nexa_crime_session_members', 'nexa_crime_cooldowns', 'nexa_crime_reputation_history', 'nexa_crime_heat_history', 'nexa_crime_locations', 'nexa_crime_audit' } } end
