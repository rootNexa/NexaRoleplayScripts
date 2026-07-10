NexaPropertyInteriorsDatabase = {}

local function coreDatabase() if GetResourceState('nexa-core') ~= 'started' then return nil end; local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end); return ok and core and core.Database or nil end
local function encode(value) local ok, encoded = pcall(json.encode, value or {}); return ok and encoded or '{}' end
local function dbCall(method, sql, params, category) local db = coreDatabase(); if not db or not db[method] then return nil, { code = NEXA_INTERIOR_ERRORS.databaseError } end; return db[method](sql, params or {}, { category = category or 'propertyinteriors.db' }) end

function NexaPropertyInteriorsDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '122_property_interiors_foundation',
        description = 'Create property interior definitions instances occupants and furniture bounds.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_interior_definitions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                interior_key VARCHAR(64) UNIQUE NOT NULL,
                interior_type VARCHAR(32) NOT NULL,
                shell_model VARCHAR(64) NULL,
                entry_point LONGTEXT NULL,
                exit_point LONGTEXT NULL,
                spawn_point LONGTEXT NULL,
                routing_strategy VARCHAR(32) NOT NULL,
                furniture_bounds LONGTEXT NULL,
                storage_points LONGTEXT NULL,
                wardrobe_points LONGTEXT NULL,
                garage_link LONGTEXT NULL,
                status VARCHAR(32) NOT NULL,
                metadata LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )]], {}, { category = 'propertyinteriors.migration.definitions' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_interior_instances (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NOT NULL,
                definition_id INT NULL,
                interior_type VARCHAR(32) NOT NULL,
                shell_model VARCHAR(64) NULL,
                routing_bucket INT UNIQUE NULL,
                entry_point LONGTEXT NULL,
                exit_point LONGTEXT NULL,
                spawn_state VARCHAR(32) NOT NULL,
                status VARCHAR(32) NOT NULL,
                configuration LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY uq_property_interior_instance (property_id)
            )]], {}, { category = 'propertyinteriors.migration.instances' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_interior_occupants (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NOT NULL,
                source INT NOT NULL,
                character_id BIGINT NULL,
                routing_bucket INT NOT NULL,
                entered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                exited_at TIMESTAMP NULL,
                metadata LONGTEXT NULL,
                INDEX idx_property_occupants (property_id, exited_at)
            )]], {}, { category = 'propertyinteriors.migration.occupants' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaPropertyInteriorsDatabase.InsertDefinition(d) return dbCall('Insert', 'INSERT INTO nexa_property_interior_definitions (interior_key, interior_type, shell_model, entry_point, exit_point, spawn_point, routing_strategy, furniture_bounds, storage_points, wardrobe_points, garage_link, status, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { d.interior_key, d.interior_type, d.shell_model, encode(d.entry_point), encode(d.exit_point), encode(d.spawn_point), d.routing_strategy, encode(d.furniture_bounds), encode(d.storage_points), encode(d.wardrobe_points), encode(d.garage_link), d.status, encode(d.metadata) }, 'propertyinteriors.definition.insert') end
function NexaPropertyInteriorsDatabase.GetDefinition(key) return dbCall('Single', 'SELECT * FROM nexa_property_interior_definitions WHERE interior_key = ? LIMIT 1', { key }, 'propertyinteriors.definition.get') end
function NexaPropertyInteriorsDatabase.ListDefinitions() return dbCall('Query', 'SELECT * FROM nexa_property_interior_definitions ORDER BY id DESC LIMIT 500', {}, 'propertyinteriors.definition.list') end
function NexaPropertyInteriorsDatabase.UpsertInstance(i) return dbCall('Update', 'INSERT INTO nexa_property_interior_instances (property_id, definition_id, interior_type, shell_model, routing_bucket, entry_point, exit_point, spawn_state, status, configuration) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE routing_bucket = VALUES(routing_bucket), spawn_state = VALUES(spawn_state), status = VALUES(status), configuration = VALUES(configuration)', { i.property_id, i.definition_id, i.interior_type, i.shell_model, i.routing_bucket, encode(i.entry_point), encode(i.exit_point), i.spawn_state, i.status, encode(i.configuration) }, 'propertyinteriors.instance.upsert') end
function NexaPropertyInteriorsDatabase.GetInstance(propertyId) return dbCall('Single', 'SELECT * FROM nexa_property_interior_instances WHERE property_id = ? LIMIT 1', { propertyId }, 'propertyinteriors.instance.get') end
function NexaPropertyInteriorsDatabase.InsertOccupant(o) return dbCall('Insert', 'INSERT INTO nexa_property_interior_occupants (property_id, source, character_id, routing_bucket, metadata) VALUES (?, ?, ?, ?, ?)', { o.property_id, o.source, o.character_id, o.routing_bucket, encode(o.metadata) }, 'propertyinteriors.occupant.insert') end
function NexaPropertyInteriorsDatabase.ExitOccupant(propertyId, source) return dbCall('Update', 'UPDATE nexa_property_interior_occupants SET exited_at = CURRENT_TIMESTAMP WHERE property_id = ? AND source = ? AND exited_at IS NULL', { propertyId, source }, 'propertyinteriors.occupant.exit') end
function NexaPropertyInteriorsDatabase.ListOccupants(propertyId) return dbCall('Query', 'SELECT * FROM nexa_property_interior_occupants WHERE property_id = ? AND exited_at IS NULL ORDER BY id ASC', { propertyId }, 'propertyinteriors.occupants.list') end
function NexaPropertyInteriorsDatabase.GetSchema() return { migration = '122_property_interiors_foundation', tables = { 'nexa_property_interior_definitions', 'nexa_property_interior_instances', 'nexa_property_interior_occupants' } } end
