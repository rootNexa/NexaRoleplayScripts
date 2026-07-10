NexaMedicalDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_MEDICAL_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'medical.db' }) end

function NexaMedicalDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '160_medical_foundation',
        description = 'Create medical states injuries treatments deaths respawns and reports.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_medical_states (id INT AUTO_INCREMENT PRIMARY KEY, character_id BIGINT UNIQUE NOT NULL, state VARCHAR(32) NOT NULL, pain INT NOT NULL DEFAULT 0, bleed_severity INT NOT NULL DEFAULT 0, is_unconscious TINYINT(1) NOT NULL DEFAULT 0, is_dead TINYINT(1) NOT NULL DEFAULT 0, last_injury_at TIMESTAMP NULL, metadata LONGTEXT NULL, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)]], {}, { category = 'medical.migration.states' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_medical_injuries (id INT AUTO_INCREMENT PRIMARY KEY, character_id BIGINT NOT NULL, injury_type VARCHAR(32) NOT NULL, severity INT NOT NULL, body_part VARCHAR(32) NULL, source_type VARCHAR(32) NULL, status VARCHAR(32) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'medical.migration.injuries' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_medical_treatments (id INT AUTO_INCREMENT PRIMARY KEY, character_id BIGINT NOT NULL, medic_character_id BIGINT NULL, treatment_type VARCHAR(64) NOT NULL, status VARCHAR(32) NOT NULL, reason VARCHAR(255) NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'medical.migration.treatments' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_medical_reports (id INT AUTO_INCREMENT PRIMARY KEY, character_id BIGINT NOT NULL, author_character_id BIGINT NULL, report_type VARCHAR(64) NOT NULL, summary TEXT NULL, status VARCHAR(32) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'medical.migration.reports' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_medical_deaths (id INT AUTO_INCREMENT PRIMARY KEY, character_id BIGINT NOT NULL, cause VARCHAR(64) NULL, declared_by BIGINT NULL, respawned_at TIMESTAMP NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'medical.migration.deaths' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaMedicalDatabase.EnsureState(characterId) return dbCall('Insert', 'INSERT INTO nexa_medical_states (character_id, state, metadata) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP', { characterId, NEXA_MEDICAL_STATE.healthy, encode({}) }, 'medical.state.ensure') end
function NexaMedicalDatabase.GetState(characterId) return dbCall('Single', 'SELECT * FROM nexa_medical_states WHERE character_id = ? LIMIT 1', { characterId }, 'medical.state.get') end
function NexaMedicalDatabase.UpdateState(characterId, s) return dbCall('Update', 'UPDATE nexa_medical_states SET state = ?, pain = ?, bleed_severity = ?, is_unconscious = ?, is_dead = ?, last_injury_at = CURRENT_TIMESTAMP, metadata = ? WHERE character_id = ?', { s.state, s.pain, s.bleed_severity, s.is_unconscious and 1 or 0, s.is_dead and 1 or 0, encode(s.metadata), characterId }, 'medical.state.update') end
function NexaMedicalDatabase.InsertInjury(i) return dbCall('Insert', 'INSERT INTO nexa_medical_injuries (character_id, injury_type, severity, body_part, source_type, status, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)', { i.character_id, i.injury_type, i.severity, i.body_part, i.source_type, i.status, encode(i.metadata) }, 'medical.injury.insert') end
function NexaMedicalDatabase.InsertTreatment(t) return dbCall('Insert', 'INSERT INTO nexa_medical_treatments (character_id, medic_character_id, treatment_type, status, reason, metadata) VALUES (?, ?, ?, ?, ?, ?)', { t.character_id, t.medic_character_id, t.treatment_type, t.status, t.reason, encode(t.metadata) }, 'medical.treatment.insert') end
function NexaMedicalDatabase.InsertReport(r) return dbCall('Insert', 'INSERT INTO nexa_medical_reports (character_id, author_character_id, report_type, summary, status, metadata) VALUES (?, ?, ?, ?, ?, ?)', { r.character_id, r.author_character_id, r.report_type, r.summary, r.status, encode(r.metadata) }, 'medical.report.insert') end
function NexaMedicalDatabase.ListReports(characterId) return dbCall('Query', 'SELECT * FROM nexa_medical_reports WHERE character_id = ? ORDER BY id DESC LIMIT 100', { characterId }, 'medical.report.list') end
function NexaMedicalDatabase.InsertDeath(d) return dbCall('Insert', 'INSERT INTO nexa_medical_deaths (character_id, cause, declared_by, metadata) VALUES (?, ?, ?, ?)', { d.character_id, d.cause, d.declared_by, encode(d.metadata) }, 'medical.death.insert') end
function NexaMedicalDatabase.GetSchema() return { migration = '160_medical_foundation', tables = { 'nexa_medical_states', 'nexa_medical_injuries', 'nexa_medical_treatments', 'nexa_medical_reports', 'nexa_medical_deaths' } } end
