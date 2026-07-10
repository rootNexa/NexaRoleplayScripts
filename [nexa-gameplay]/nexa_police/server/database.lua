NexaPoliceDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_POLICE_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'police.db' }) end

function NexaPoliceDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '161_police_foundation',
        description = 'Create police agencies arrests restraints searches seizures and checks.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_police_agencies (id INT AUTO_INCREMENT PRIMARY KEY, agency_key VARCHAR(64) UNIQUE NOT NULL, label VARCHAR(128) NOT NULL, agency_type VARCHAR(32) NOT NULL, organization_id INT NULL, enabled TINYINT(1) NOT NULL DEFAULT 1, metadata LONGTEXT NULL)]], {}, { category = 'police.migration.agencies' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_police_arrests (id INT AUTO_INCREMENT PRIMARY KEY, subject_character_id BIGINT NOT NULL, officer_character_id BIGINT NULL, agency_key VARCHAR(64) NULL, reason VARCHAR(255) NOT NULL, status VARCHAR(32) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'police.migration.arrests' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_police_restraints (id INT AUTO_INCREMENT PRIMARY KEY, subject_character_id BIGINT NOT NULL, officer_character_id BIGINT NULL, restraint_type VARCHAR(32) NOT NULL, enabled TINYINT(1) NOT NULL, reason VARCHAR(255) NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'police.migration.restraints' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_police_searches (id INT AUTO_INCREMENT PRIMARY KEY, subject_character_id BIGINT NOT NULL, officer_character_id BIGINT NULL, search_type VARCHAR(32) NOT NULL, reason VARCHAR(255) NOT NULL, result LONGTEXT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'police.migration.searches' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_police_seizures (id INT AUTO_INCREMENT PRIMARY KEY, subject_character_id BIGINT NULL, officer_character_id BIGINT NULL, item_reference VARCHAR(128) NULL, reason VARCHAR(255) NOT NULL, evidence_id INT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'police.migration.seizures' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaPoliceDatabase.InsertAgency(a) return dbCall('Insert', 'INSERT INTO nexa_police_agencies (agency_key, label, agency_type, organization_id, enabled, metadata) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label), agency_type = VALUES(agency_type), organization_id = VALUES(organization_id), enabled = VALUES(enabled), metadata = VALUES(metadata)', { a.agency_key, a.label, a.agency_type, a.organization_id, a.enabled and 1 or 0, encode(a.metadata) }, 'police.agency.upsert') end
function NexaPoliceDatabase.GetAgency(key) return dbCall('Single', 'SELECT * FROM nexa_police_agencies WHERE agency_key = ? LIMIT 1', { key }, 'police.agency.get') end
function NexaPoliceDatabase.ListAgencies() return dbCall('Query', 'SELECT * FROM nexa_police_agencies ORDER BY agency_key ASC', {}, 'police.agency.list') end
function NexaPoliceDatabase.InsertArrest(a) return dbCall('Insert', 'INSERT INTO nexa_police_arrests (subject_character_id, officer_character_id, agency_key, reason, status, metadata) VALUES (?, ?, ?, ?, ?, ?)', { a.subject_character_id, a.officer_character_id, a.agency_key, a.reason, a.status, encode(a.metadata) }, 'police.arrest.insert') end
function NexaPoliceDatabase.InsertRestraint(r) return dbCall('Insert', 'INSERT INTO nexa_police_restraints (subject_character_id, officer_character_id, restraint_type, enabled, reason, metadata) VALUES (?, ?, ?, ?, ?, ?)', { r.subject_character_id, r.officer_character_id, r.restraint_type, r.enabled and 1 or 0, r.reason, encode(r.metadata) }, 'police.restraint.insert') end
function NexaPoliceDatabase.InsertSearch(s) return dbCall('Insert', 'INSERT INTO nexa_police_searches (subject_character_id, officer_character_id, search_type, reason, result, metadata) VALUES (?, ?, ?, ?, ?, ?)', { s.subject_character_id, s.officer_character_id, s.search_type, s.reason, encode(s.result), encode(s.metadata) }, 'police.search.insert') end
function NexaPoliceDatabase.InsertSeizure(s) return dbCall('Insert', 'INSERT INTO nexa_police_seizures (subject_character_id, officer_character_id, item_reference, reason, evidence_id, metadata) VALUES (?, ?, ?, ?, ?, ?)', { s.subject_character_id, s.officer_character_id, s.item_reference, s.reason, s.evidence_id, encode(s.metadata) }, 'police.seizure.insert') end
function NexaPoliceDatabase.GetSchema() return { migration = '161_police_foundation', tables = { 'nexa_police_agencies', 'nexa_police_arrests', 'nexa_police_restraints', 'nexa_police_searches', 'nexa_police_seizures' } } end
