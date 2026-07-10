NexaEmsDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_EMS_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'ems.db' }) end

function NexaEmsDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false end
    db.RegisterMigration({
        id = '165_ems_foundation',
        description = 'Create EMS inspections transports and hospital workflow records.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_ems_inspections (id INT AUTO_INCREMENT PRIMARY KEY, patient_character_id BIGINT NOT NULL, provider_character_id BIGINT NULL, triage_status VARCHAR(32) NULL, summary TEXT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'ems.migration.inspections' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_ems_transports (id INT AUTO_INCREMENT PRIMARY KEY, patient_character_id BIGINT NOT NULL, provider_character_id BIGINT NULL, vehicle_reference VARCHAR(128) NULL, hospital_key VARCHAR(64) NULL, status VARCHAR(32) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, completed_at TIMESTAMP NULL, metadata LONGTEXT NULL)]], {}, { category = 'ems.migration.transports' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_ems_hospital_records (id INT AUTO_INCREMENT PRIMARY KEY, patient_character_id BIGINT NOT NULL, provider_character_id BIGINT NULL, hospital_key VARCHAR(64) NOT NULL, record_type VARCHAR(64) NOT NULL, summary TEXT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'ems.migration.records' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaEmsDatabase.InsertInspection(i) return dbCall('Insert', 'INSERT INTO nexa_ems_inspections (patient_character_id, provider_character_id, triage_status, summary, metadata) VALUES (?, ?, ?, ?, ?)', { i.patient_character_id, i.provider_character_id, i.triage_status, i.summary, encode(i.metadata) }, 'ems.inspection.insert') end
function NexaEmsDatabase.InsertTransport(t) return dbCall('Insert', 'INSERT INTO nexa_ems_transports (patient_character_id, provider_character_id, vehicle_reference, hospital_key, status, metadata) VALUES (?, ?, ?, ?, ?, ?)', { t.patient_character_id, t.provider_character_id, t.vehicle_reference, t.hospital_key, t.status, encode(t.metadata) }, 'ems.transport.insert') end
function NexaEmsDatabase.CompleteTransport(id, status) return dbCall('Update', 'UPDATE nexa_ems_transports SET status = ?, completed_at = CURRENT_TIMESTAMP WHERE id = ? AND status IN (?, ?)', { status, id, NEXA_EMS_TRANSPORT_STATUS.active, NEXA_EMS_TRANSPORT_STATUS.loaded }, 'ems.transport.complete') end
function NexaEmsDatabase.InsertHospitalRecord(r) return dbCall('Insert', 'INSERT INTO nexa_ems_hospital_records (patient_character_id, provider_character_id, hospital_key, record_type, summary, metadata) VALUES (?, ?, ?, ?, ?, ?)', { r.patient_character_id, r.provider_character_id, r.hospital_key, r.record_type, r.summary, encode(r.metadata) }, 'ems.record.insert') end
function NexaEmsDatabase.GetSchema() return { migration = '165_ems_foundation', tables = { 'nexa_ems_inspections', 'nexa_ems_transports', 'nexa_ems_hospital_records' } } end
