NexaBetaDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_BETA_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'beta.db' }) end

function NexaBetaDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false end
    db.RegisterMigration({
        id = '180_beta_readiness',
        description = 'Create GP18 UI preferences creator registries admin settings feature flags performance baselines and release metadata.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_ui_preferences (id INT AUTO_INCREMENT PRIMARY KEY, subject_type VARCHAR(32) NOT NULL, subject_id VARCHAR(64) NOT NULL, preference_key VARCHAR(64) NOT NULL, value_json LONGTEXT NULL, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, UNIQUE KEY uniq_nexa_ui_pref (subject_type, subject_id, preference_key))]], {}, { category = 'beta.migration.ui_preferences' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_creator_registries (id INT AUTO_INCREMENT PRIMARY KEY, creator_type VARCHAR(64) UNIQUE NOT NULL, label VARCHAR(128) NOT NULL, resource_name VARCHAR(64) NULL, enabled TINYINT(1) NOT NULL DEFAULT 1, metadata LONGTEXT NULL, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)]], {}, { category = 'beta.migration.creator_registries' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_admin_settings (id INT AUTO_INCREMENT PRIMARY KEY, setting_key VARCHAR(64) UNIQUE NOT NULL, value_json LONGTEXT NULL, updated_by VARCHAR(64) NULL, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)]], {}, { category = 'beta.migration.admin_settings' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_feature_flags (id INT AUTO_INCREMENT PRIMARY KEY, flag_key VARCHAR(96) UNIQUE NOT NULL, enabled TINYINT(1) NOT NULL DEFAULT 0, scope VARCHAR(32) NOT NULL DEFAULT 'global', value_json LONGTEXT NULL, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)]], {}, { category = 'beta.migration.feature_flags' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_performance_baselines (id INT AUTO_INCREMENT PRIMARY KEY, snapshot_key VARCHAR(96) NOT NULL, cpu_ms INT NULL, memory_kb INT NULL, net_events INT NULL, sql_queries INT NULL, metadata LONGTEXT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)]], {}, { category = 'beta.migration.performance' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_release_metadata (id INT AUTO_INCREMENT PRIMARY KEY, release_key VARCHAR(96) UNIQUE NOT NULL, release_channel VARCHAR(32) NOT NULL, status VARCHAR(32) NOT NULL, version VARCHAR(32) NOT NULL, metadata LONGTEXT NULL, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)]], {}, { category = 'beta.migration.release' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaBetaDatabase.UpsertCreator(c) return dbCall('Insert', 'INSERT INTO nexa_creator_registries (creator_type, label, resource_name, enabled, metadata) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label), resource_name = VALUES(resource_name), enabled = VALUES(enabled), metadata = VALUES(metadata)', { c.creator_type, c.label, c.resource_name, c.enabled and 1 or 0, encode(c.metadata) }, 'beta.creator.upsert') end
function NexaBetaDatabase.ListCreators() return dbCall('Query', 'SELECT * FROM nexa_creator_registries ORDER BY creator_type ASC LIMIT 200', {}, 'beta.creator.list') end
function NexaBetaDatabase.UpsertFeatureFlag(f) return dbCall('Insert', 'INSERT INTO nexa_feature_flags (flag_key, enabled, scope, value_json) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE enabled = VALUES(enabled), scope = VALUES(scope), value_json = VALUES(value_json)', { f.flag_key, f.enabled and 1 or 0, f.scope or 'global', encode(f.value) }, 'beta.flag.upsert') end
function NexaBetaDatabase.InsertPerformanceSnapshot(s) return dbCall('Insert', 'INSERT INTO nexa_performance_baselines (snapshot_key, cpu_ms, memory_kb, net_events, sql_queries, metadata) VALUES (?, ?, ?, ?, ?, ?)', { s.snapshot_key, s.cpu_ms, s.memory_kb, s.net_events, s.sql_queries, encode(s.metadata) }, 'beta.performance.insert') end
function NexaBetaDatabase.UpsertRelease(r) return dbCall('Insert', 'INSERT INTO nexa_release_metadata (release_key, release_channel, status, version, metadata) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE release_channel = VALUES(release_channel), status = VALUES(status), version = VALUES(version), metadata = VALUES(metadata)', { r.release_key, r.release_channel, r.status, r.version, encode(r.metadata) }, 'beta.release.upsert') end
function NexaBetaDatabase.GetSchema() return { migration = '180_beta_readiness', tables = { 'nexa_ui_preferences', 'nexa_creator_registries', 'nexa_admin_settings', 'nexa_feature_flags', 'nexa_performance_baselines', 'nexa_release_metadata' } } end
