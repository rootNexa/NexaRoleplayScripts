NexaDocumentsDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = 'DATABASE_ERROR' } end; return db[method](sql, params or {}, { category = category or 'documents.db' }) end

function NexaDocumentsDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false end
    db.RegisterMigration({
        id = '172_documents_digital',
        description = 'Create digital documents versions signatures shares and visibility records.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_document_records (id INT AUTO_INCREMENT PRIMARY KEY, document_number VARCHAR(64) UNIQUE NOT NULL, document_type VARCHAR(64) NOT NULL, owner_character_id BIGINT NULL, status VARCHAR(32) NOT NULL, visibility VARCHAR(32) NOT NULL DEFAULT 'private', created_by BIGINT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'documents.migration.records' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_document_versions (id INT AUTO_INCREMENT PRIMARY KEY, document_id INT NOT NULL, version INT NOT NULL, content_json LONGTEXT NULL, created_by BIGINT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)]], {}, { category = 'documents.migration.versions' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_document_signatures (id INT AUTO_INCREMENT PRIMARY KEY, document_id INT NOT NULL, signer_character_id BIGINT NOT NULL, signature_hash VARCHAR(128) NOT NULL, signed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'documents.migration.signatures' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_document_shares (id INT AUTO_INCREMENT PRIMARY KEY, document_id INT NOT NULL, target_type VARCHAR(32) NOT NULL, target_id VARCHAR(64) NOT NULL, permission VARCHAR(32) NOT NULL, expires_at TIMESTAMP NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'documents.migration.shares' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaDocumentsDatabase.InsertDocument(d) return dbCall('Insert', 'INSERT INTO nexa_document_records (document_number, document_type, owner_character_id, status, visibility, created_by, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)', { d.document_number, d.document_type, d.owner_character_id, d.status, d.visibility, d.created_by, encode(d.metadata) }, 'documents.record.insert') end
function NexaDocumentsDatabase.InsertVersion(v) return dbCall('Insert', 'INSERT INTO nexa_document_versions (document_id, version, content_json, created_by) VALUES (?, ?, ?, ?)', { v.document_id, v.version, encode(v.content), v.created_by }, 'documents.version.insert') end
function NexaDocumentsDatabase.InsertSignature(s) return dbCall('Insert', 'INSERT INTO nexa_document_signatures (document_id, signer_character_id, signature_hash, metadata) VALUES (?, ?, ?, ?)', { s.document_id, s.signer_character_id, s.signature_hash, encode(s.metadata) }, 'documents.signature.insert') end
function NexaDocumentsDatabase.InsertShare(s) return dbCall('Insert', 'INSERT INTO nexa_document_shares (document_id, target_type, target_id, permission, expires_at, metadata) VALUES (?, ?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? HOUR), ?)', { s.document_id, s.target_type, s.target_id, s.permission, s.expires_hours or 24, encode(s.metadata) }, 'documents.share.insert') end
function NexaDocumentsDatabase.GetSchema() return { migration = '172_documents_digital', tables = { 'nexa_document_records', 'nexa_document_versions', 'nexa_document_signatures', 'nexa_document_shares' } } end
