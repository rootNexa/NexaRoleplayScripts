NexaDrugsDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_DRUG_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'drugs.db' }) end

function NexaDrugsDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '152_drugs_foundation',
        description = 'Create abstract drug definitions grow sites batches processing jobs and audit.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_drug_definitions (id INT AUTO_INCREMENT PRIMARY KEY, drug_key VARCHAR(64) UNIQUE NOT NULL, label VARCHAR(128) NOT NULL, drug_type VARCHAR(32) NOT NULL, status VARCHAR(32) NOT NULL, abstract_profile LONGTEXT NULL, quality_policy LONGTEXT NULL, packaging_policy LONGTEXT NULL, metadata LONGTEXT NULL)]], {}, { category = 'drugs.migration.definitions' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_drug_grow_sites (id INT AUTO_INCREMENT PRIMARY KEY, site_key VARCHAR(64) UNIQUE NOT NULL, drug_definition_id INT NOT NULL, status VARCHAR(32) NOT NULL, property_id INT NULL, position LONGTEXT NULL, capacity INT NOT NULL DEFAULT 1, access_rules LONGTEXT NULL, metadata LONGTEXT NULL)]], {}, { category = 'drugs.migration.grow_sites' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_drug_batches (id INT AUTO_INCREMENT PRIMARY KEY, drug_definition_id INT NOT NULL, grow_site_id INT NULL, character_id BIGINT NULL, status VARCHAR(32) NOT NULL, quality INT NOT NULL DEFAULT 1, amount INT NOT NULL DEFAULT 1, ready_at TIMESTAMP NULL, idempotency_key VARCHAR(128) UNIQUE NULL, metadata LONGTEXT NULL)]], {}, { category = 'drugs.migration.batches' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_drug_processing_jobs (id INT AUTO_INCREMENT PRIMARY KEY, drug_definition_id INT NOT NULL, batch_id INT NULL, character_id BIGINT NULL, status VARCHAR(32) NOT NULL, started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, completes_at TIMESTAMP NULL, completed_at TIMESTAMP NULL, quality_result INT NULL, idempotency_key VARCHAR(128) UNIQUE NULL, metadata LONGTEXT NULL)]], {}, { category = 'drugs.migration.processing' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_drug_audit (id INT AUTO_INCREMENT PRIMARY KEY, drug_definition_id INT NULL, batch_id INT NULL, action VARCHAR(64) NOT NULL, actor_character_id BIGINT NULL, reason VARCHAR(255) NULL, result VARCHAR(32) NOT NULL, error_code VARCHAR(64) NULL, correlation_id VARCHAR(128) NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'drugs.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaDrugsDatabase.InsertDefinition(d) return dbCall('Insert', 'INSERT INTO nexa_drug_definitions (drug_key, label, drug_type, status, abstract_profile, quality_policy, packaging_policy, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', { d.drug_key, d.label, d.drug_type, d.status, encode(d.abstract_profile), encode(d.quality_policy), encode(d.packaging_policy), encode(d.metadata) }, 'drugs.definition.insert') end
function NexaDrugsDatabase.GetDefinition(idOrKey) local id = tonumber(idOrKey); if id then return dbCall('Single', 'SELECT * FROM nexa_drug_definitions WHERE id = ? LIMIT 1', { id }, 'drugs.definition.get') end; return dbCall('Single', 'SELECT * FROM nexa_drug_definitions WHERE drug_key = ? LIMIT 1', { tostring(idOrKey) }, 'drugs.definition.key') end
function NexaDrugsDatabase.ListDefinitions() return dbCall('Query', 'SELECT * FROM nexa_drug_definitions ORDER BY id DESC LIMIT 500', {}, 'drugs.definition.list') end
function NexaDrugsDatabase.InsertGrowSite(s) return dbCall('Insert', 'INSERT INTO nexa_drug_grow_sites (site_key, drug_definition_id, status, property_id, position, capacity, access_rules, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', { s.site_key, s.drug_definition_id, s.status, s.property_id, encode(s.position), s.capacity, encode(s.access_rules), encode(s.metadata) }, 'drugs.grow_site.insert') end
function NexaDrugsDatabase.GetGrowSite(id) return dbCall('Single', 'SELECT * FROM nexa_drug_grow_sites WHERE id = ? OR site_key = ? LIMIT 1', { tonumber(id) or 0, tostring(id) }, 'drugs.grow_site.get') end
function NexaDrugsDatabase.InsertBatch(b) return dbCall('Insert', 'INSERT INTO nexa_drug_batches (drug_definition_id, grow_site_id, character_id, status, quality, amount, ready_at, idempotency_key, metadata) VALUES (?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?), ?, ?)', { b.drug_definition_id, b.grow_site_id, b.character_id, b.status, b.quality, b.amount, b.ready_at, b.idempotency_key, encode(b.metadata) }, 'drugs.batch.insert') end
function NexaDrugsDatabase.GetBatch(id) return dbCall('Single', 'SELECT * FROM nexa_drug_batches WHERE id = ? LIMIT 1', { id }, 'drugs.batch.get') end
function NexaDrugsDatabase.SetBatchStatus(id, status) return dbCall('Update', 'UPDATE nexa_drug_batches SET status = ? WHERE id = ?', { status, id }, 'drugs.batch.status') end
function NexaDrugsDatabase.InsertProcessingJob(j) return dbCall('Insert', 'INSERT INTO nexa_drug_processing_jobs (drug_definition_id, batch_id, character_id, status, completes_at, quality_result, idempotency_key, metadata) VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), ?, ?, ?)', { j.drug_definition_id, j.batch_id, j.character_id, j.status, j.completes_at, j.quality_result, j.idempotency_key, encode(j.metadata) }, 'drugs.processing.insert') end
function NexaDrugsDatabase.GetProcessingJob(id) return dbCall('Single', 'SELECT * FROM nexa_drug_processing_jobs WHERE id = ? LIMIT 1', { id }, 'drugs.processing.get') end
function NexaDrugsDatabase.GetSchema() return { migration = '152_drugs_foundation', tables = { 'nexa_drug_definitions', 'nexa_drug_grow_sites', 'nexa_drug_batches', 'nexa_drug_processing_jobs', 'nexa_drug_audit' } } end
