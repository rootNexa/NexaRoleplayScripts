NexaRadioDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_RADIO_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'radio.db' }) end

function NexaRadioDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false end
    db.RegisterMigration({
        id = '171_radio_foundation',
        description = 'Create radio frequencies channels permissions memberships and priorities.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_radio_channels (id INT AUTO_INCREMENT PRIMARY KEY, channel_key VARCHAR(64) UNIQUE NOT NULL, label VARCHAR(128) NOT NULL, frequency VARCHAR(32) NOT NULL, organization_id INT NULL, encryption_class VARCHAR(32) NOT NULL, priority INT NOT NULL DEFAULT 3, enabled TINYINT(1) NOT NULL DEFAULT 1, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'radio.migration.channels' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_radio_memberships (id INT AUTO_INCREMENT PRIMARY KEY, channel_key VARCHAR(64) NOT NULL, character_id BIGINT NOT NULL, role VARCHAR(32) NULL, joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, metadata LONGTEXT NULL)]], {}, { category = 'radio.migration.memberships' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_radio_permissions (id INT AUTO_INCREMENT PRIMARY KEY, channel_key VARCHAR(64) NOT NULL, permission VARCHAR(128) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)]], {}, { category = 'radio.migration.permissions' })
            db.Query([[CREATE INDEX IF NOT EXISTS idx_nexa_radio_membership_character ON nexa_radio_memberships (character_id, channel_key)]], {}, { category = 'radio.migration.index.membership_character' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaRadioDatabase.UpsertChannel(c) return dbCall('Insert', 'INSERT INTO nexa_radio_channels (channel_key, label, frequency, organization_id, encryption_class, priority, enabled, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label), frequency = VALUES(frequency), organization_id = VALUES(organization_id), encryption_class = VALUES(encryption_class), priority = VALUES(priority), enabled = VALUES(enabled), metadata = VALUES(metadata)', { c.channel_key, c.label, c.frequency, c.organization_id, c.encryption_class, c.priority, c.enabled and 1 or 0, encode(c.metadata) }, 'radio.channel.upsert') end
function NexaRadioDatabase.ListChannels() return dbCall('Query', 'SELECT * FROM nexa_radio_channels WHERE enabled = 1 ORDER BY priority ASC, channel_key ASC LIMIT 200', {}, 'radio.channel.list') end
function NexaRadioDatabase.InsertMembership(m) return dbCall('Insert', 'INSERT INTO nexa_radio_memberships (channel_key, character_id, role, metadata) VALUES (?, ?, ?, ?)', { m.channel_key, m.character_id, m.role, encode(m.metadata) }, 'radio.membership.insert') end
function NexaRadioDatabase.DeleteMembership(channelKey, characterId) return dbCall('Delete', 'DELETE FROM nexa_radio_memberships WHERE channel_key = ? AND character_id = ?', { channelKey, characterId }, 'radio.membership.delete') end
function NexaRadioDatabase.SetPriority(channelKey, priority) return dbCall('Update', 'UPDATE nexa_radio_channels SET priority = ? WHERE channel_key = ?', { priority, channelKey }, 'radio.channel.priority') end
function NexaRadioDatabase.GetSchema() return { migration = '171_radio_foundation', tables = { 'nexa_radio_channels', 'nexa_radio_memberships', 'nexa_radio_permissions' } } end
