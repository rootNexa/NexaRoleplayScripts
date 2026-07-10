NexaPhoneDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = 'DATABASE_ERROR' } end; return db[method](sql, params or {}, { category = category or 'phone.db' }) end

function NexaPhoneDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false end
    db.RegisterMigration({
        id = '170_phone_communication',
        description = 'Create phone contacts chats messages calls groups notifications favorites and preferences.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_phone_contacts (id INT AUTO_INCREMENT PRIMARY KEY, owner_character_id BIGINT NOT NULL, display_name VARCHAR(128) NOT NULL, phone_number VARCHAR(32) NOT NULL, favorite TINYINT(1) NOT NULL DEFAULT 0, notes TEXT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'phone.migration.contacts' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_phone_chats (id INT AUTO_INCREMENT PRIMARY KEY, owner_character_id BIGINT NOT NULL, chat_type VARCHAR(32) NOT NULL, title VARCHAR(128) NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'phone.migration.chats' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_phone_messages (id INT AUTO_INCREMENT PRIMARY KEY, chat_id INT NULL, sender_character_id BIGINT NULL, recipient_number VARCHAR(32) NULL, body TEXT NOT NULL, status VARCHAR(32) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'phone.migration.messages' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_phone_calls (id INT AUTO_INCREMENT PRIMARY KEY, owner_character_id BIGINT NOT NULL, phone_number VARCHAR(32) NULL, direction VARCHAR(16) NOT NULL, status VARCHAR(32) NOT NULL, started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, ended_at TIMESTAMP NULL, metadata LONGTEXT NULL)]], {}, { category = 'phone.migration.calls' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_phone_groups (id INT AUTO_INCREMENT PRIMARY KEY, owner_character_id BIGINT NOT NULL, label VARCHAR(128) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'phone.migration.groups' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_phone_notifications (id INT AUTO_INCREMENT PRIMARY KEY, owner_character_id BIGINT NOT NULL, notification_type VARCHAR(64) NOT NULL, title VARCHAR(128) NOT NULL, body TEXT NULL, read_at TIMESTAMP NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'phone.migration.notifications' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_phone_preferences (id INT AUTO_INCREMENT PRIMARY KEY, owner_character_id BIGINT UNIQUE NOT NULL, mode VARCHAR(16) NOT NULL DEFAULT 'dark', preferences_json LONGTEXT NULL, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)]], {}, { category = 'phone.migration.preferences' })
            db.Query([[CREATE INDEX IF NOT EXISTS idx_nexa_phone_contacts_owner ON nexa_phone_contacts (owner_character_id, phone_number)]], {}, { category = 'phone.migration.index.contacts_owner' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaPhoneDatabase.InsertContact(c) return dbCall('Insert', 'INSERT INTO nexa_phone_contacts (owner_character_id, display_name, phone_number, favorite, notes, metadata) VALUES (?, ?, ?, ?, ?, ?)', { c.owner_character_id, c.display_name, c.phone_number, c.favorite and 1 or 0, c.notes, encode(c.metadata) }, 'phone.contact.insert') end
function NexaPhoneDatabase.InsertCall(c) return dbCall('Insert', 'INSERT INTO nexa_phone_calls (owner_character_id, phone_number, direction, status, metadata) VALUES (?, ?, ?, ?, ?)', { c.owner_character_id, c.phone_number, c.direction, c.status, encode(c.metadata) }, 'phone.call.insert') end
function NexaPhoneDatabase.InsertGroup(g) return dbCall('Insert', 'INSERT INTO nexa_phone_groups (owner_character_id, label, metadata) VALUES (?, ?, ?)', { g.owner_character_id, g.label, encode(g.metadata) }, 'phone.group.insert') end
function NexaPhoneDatabase.InsertPreference(owner, prefs) return dbCall('Insert', 'INSERT INTO nexa_phone_preferences (owner_character_id, mode, preferences_json) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE mode = VALUES(mode), preferences_json = VALUES(preferences_json)', { owner, prefs.mode or 'dark', encode(prefs) }, 'phone.preferences.upsert') end
function NexaPhoneDatabase.GetSchema() return { migration = '170_phone_communication', tables = { 'nexa_phone_contacts', 'nexa_phone_chats', 'nexa_phone_messages', 'nexa_phone_calls', 'nexa_phone_groups', 'nexa_phone_notifications', 'nexa_phone_preferences' } } end
