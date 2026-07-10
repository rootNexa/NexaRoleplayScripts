NexaMdtDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_MDT_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'mdt.db' }) end

function NexaMdtDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false end
    db.RegisterMigration({
        id = '166_mdt_domain',
        description = 'Create MDT cases reports warrants bolos notes and links.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_mdt_cases (id INT AUTO_INCREMENT PRIMARY KEY, case_number VARCHAR(64) UNIQUE NOT NULL, title VARCHAR(160) NOT NULL, mdt_type VARCHAR(32) NOT NULL, status VARCHAR(32) NOT NULL, created_by BIGINT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'mdt.migration.cases' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_mdt_reports (id INT AUTO_INCREMENT PRIMARY KEY, case_id INT NULL, report_type VARCHAR(64) NOT NULL, title VARCHAR(160) NOT NULL, narrative LONGTEXT NULL, status VARCHAR(32) NOT NULL, revision INT NOT NULL DEFAULT 1, created_by BIGINT NULL, finalized_at TIMESTAMP NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'mdt.migration.reports' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_mdt_warrants (id INT AUTO_INCREMENT PRIMARY KEY, case_id INT NULL, subject_character_id BIGINT NULL, warrant_type VARCHAR(64) NOT NULL, reason VARCHAR(255) NOT NULL, status VARCHAR(32) NOT NULL, requested_by BIGINT NULL, approved_by BIGINT NULL, expires_at TIMESTAMP NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'mdt.migration.warrants' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_mdt_bolos (id INT AUTO_INCREMENT PRIMARY KEY, target_type VARCHAR(32) NOT NULL, target_reference VARCHAR(128) NOT NULL, reason VARCHAR(255) NOT NULL, status VARCHAR(32) NOT NULL, created_by BIGINT NULL, expires_at TIMESTAMP NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'mdt.migration.bolos' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_mdt_notes (id INT AUTO_INCREMENT PRIMARY KEY, case_id INT NULL, subject_reference VARCHAR(128) NULL, visibility VARCHAR(32) NOT NULL, note TEXT NOT NULL, created_by BIGINT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'mdt.migration.notes' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_mdt_links (id INT AUTO_INCREMENT PRIMARY KEY, case_id INT NOT NULL, entity_type VARCHAR(64) NOT NULL, entity_reference VARCHAR(128) NOT NULL, created_by BIGINT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'mdt.migration.links' })
            db.Query([[CREATE INDEX IF NOT EXISTS idx_nexa_mdt_reports_case ON nexa_mdt_reports (case_id, status)]], {}, { category = 'mdt.migration.index.reports_case' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaMdtDatabase.InsertCase(c) return dbCall('Insert', 'INSERT INTO nexa_mdt_cases (case_number, title, mdt_type, status, created_by, metadata) VALUES (?, ?, ?, ?, ?, ?)', { c.case_number, c.title, c.mdt_type, c.status, c.created_by, encode(c.metadata) }, 'mdt.case.insert') end
function NexaMdtDatabase.InsertReport(r) return dbCall('Insert', 'INSERT INTO nexa_mdt_reports (case_id, report_type, title, narrative, status, created_by, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)', { r.case_id, r.report_type, r.title, r.narrative, r.status, r.created_by, encode(r.metadata) }, 'mdt.report.insert') end
function NexaMdtDatabase.FinalizeReport(id) return dbCall('Update', 'UPDATE nexa_mdt_reports SET status = ?, finalized_at = CURRENT_TIMESTAMP WHERE id = ? AND status IN (?, ?)', { NEXA_MDT_RECORD_STATUS.finalized, id, NEXA_MDT_RECORD_STATUS.draft, NEXA_MDT_RECORD_STATUS.submitted }, 'mdt.report.finalize') end
function NexaMdtDatabase.InsertWarrant(w) return dbCall('Insert', 'INSERT INTO nexa_mdt_warrants (case_id, subject_character_id, warrant_type, reason, status, requested_by, approved_by, expires_at, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? HOUR), ?)', { w.case_id, w.subject_character_id, w.warrant_type, w.reason, w.status, w.requested_by, w.approved_by, w.expires_hours or 72, encode(w.metadata) }, 'mdt.warrant.insert') end
function NexaMdtDatabase.InsertBolo(b) return dbCall('Insert', 'INSERT INTO nexa_mdt_bolos (target_type, target_reference, reason, status, created_by, expires_at, metadata) VALUES (?, ?, ?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? HOUR), ?)', { b.target_type, b.target_reference, b.reason, b.status, b.created_by, b.expires_hours or 24, encode(b.metadata) }, 'mdt.bolo.insert') end
function NexaMdtDatabase.InsertNote(n) return dbCall('Insert', 'INSERT INTO nexa_mdt_notes (case_id, subject_reference, visibility, note, created_by, metadata) VALUES (?, ?, ?, ?, ?, ?)', { n.case_id, n.subject_reference, n.visibility, n.note, n.created_by, encode(n.metadata) }, 'mdt.note.insert') end
function NexaMdtDatabase.GetSchema() return { migration = '166_mdt_domain', tables = { 'nexa_mdt_cases', 'nexa_mdt_reports', 'nexa_mdt_warrants', 'nexa_mdt_bolos', 'nexa_mdt_notes', 'nexa_mdt_links' } } end
