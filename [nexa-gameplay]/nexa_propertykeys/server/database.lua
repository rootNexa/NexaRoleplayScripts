NexaPropertyKeysDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_PROPERTYKEY_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'propertykeys.db' }) end

function NexaPropertyKeysDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '121_propertykeys_foundation',
        description = 'Create property keys doors and access history.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_keys (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NOT NULL,
                holder_type VARCHAR(32) NOT NULL,
                holder_id VARCHAR(64) NOT NULL,
                key_type VARCHAR(32) NOT NULL,
                permissions LONGTEXT NULL,
                status VARCHAR(32) NOT NULL,
                issued_by BIGINT NULL,
                issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                expires_at TIMESTAMP NULL,
                revoked_at TIMESTAMP NULL,
                metadata LONGTEXT NULL,
                UNIQUE KEY uq_property_key_holder (property_id, holder_type, holder_id, key_type, status),
                INDEX idx_property_key_holder (holder_type, holder_id, status)
            )]], {}, { category = 'propertykeys.migration.keys' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_doors (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NOT NULL,
                door_key VARCHAR(64) NOT NULL,
                label VARCHAR(128) NULL,
                locked TINYINT(1) NOT NULL DEFAULT 1,
                definition LONGTEXT NULL,
                metadata LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY uq_property_door (property_id, door_key)
            )]], {}, { category = 'propertykeys.migration.doors' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_access_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NOT NULL,
                holder_type VARCHAR(32) NULL,
                holder_id VARCHAR(64) NULL,
                action VARCHAR(64) NOT NULL,
                result VARCHAR(32) NOT NULL,
                door_key VARCHAR(64) NULL,
                metadata LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )]], {}, { category = 'propertykeys.migration.history' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaPropertyKeysDatabase.InsertKey(k) return dbCall('Insert', 'INSERT INTO nexa_property_keys (property_id, holder_type, holder_id, key_type, permissions, status, issued_by, expires_at, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?), ?)', { k.property_id, k.holder_type, tostring(k.holder_id), k.key_type, encode(k.permissions), k.status, k.issued_by, k.expires_at, encode(k.metadata) }, 'propertykeys.key.insert') end
function NexaPropertyKeysDatabase.GetKey(propertyId, holderType, holderId) return dbCall('Single', 'SELECT * FROM nexa_property_keys WHERE property_id = ? AND holder_type = ? AND holder_id = ? AND status = ? AND (expires_at IS NULL OR expires_at > CURRENT_TIMESTAMP) LIMIT 1', { propertyId, holderType, tostring(holderId), NEXA_PROPERTY_KEY_STATUS.active }, 'propertykeys.key.get') end
function NexaPropertyKeysDatabase.ListKeys(propertyId) return dbCall('Query', 'SELECT * FROM nexa_property_keys WHERE property_id = ? AND status = ? ORDER BY id ASC', { propertyId, NEXA_PROPERTY_KEY_STATUS.active }, 'propertykeys.key.list') end
function NexaPropertyKeysDatabase.RevokeKey(id) return dbCall('Update', 'UPDATE nexa_property_keys SET status = ?, revoked_at = CURRENT_TIMESTAMP WHERE id = ?', { NEXA_PROPERTY_KEY_STATUS.revoked, id }, 'propertykeys.key.revoke') end
function NexaPropertyKeysDatabase.InsertDoor(d) return dbCall('Insert', 'INSERT INTO nexa_property_doors (property_id, door_key, label, locked, definition, metadata) VALUES (?, ?, ?, ?, ?, ?)', { d.property_id, d.door_key, d.label, d.locked and 1 or 0, encode(d.definition), encode(d.metadata) }, 'propertykeys.door.insert') end
function NexaPropertyKeysDatabase.ListDoors(propertyId) return dbCall('Query', 'SELECT * FROM nexa_property_doors WHERE property_id = ? ORDER BY id ASC', { propertyId }, 'propertykeys.door.list') end
function NexaPropertyKeysDatabase.SetDoorLocked(propertyId, doorKey, locked) return dbCall('Update', 'UPDATE nexa_property_doors SET locked = ? WHERE property_id = ? AND door_key = ?', { locked and 1 or 0, propertyId, doorKey }, 'propertykeys.door.lock') end
function NexaPropertyKeysDatabase.InsertHistory(h) return dbCall('Insert', 'INSERT INTO nexa_property_access_history (property_id, holder_type, holder_id, action, result, door_key, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)', { h.property_id, h.holder_type, tostring(h.holder_id), h.action, h.result, h.door_key, encode(h.metadata) }, 'propertykeys.history.insert') end
function NexaPropertyKeysDatabase.GetSchema() return { migration = '121_propertykeys_foundation', tables = { 'nexa_property_keys', 'nexa_property_doors', 'nexa_property_access_history' } } end
