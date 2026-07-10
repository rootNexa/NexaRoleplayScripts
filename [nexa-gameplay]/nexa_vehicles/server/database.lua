NexaVehiclesDatabase = {}

local function coreDatabase()
    if GetResourceState('nexa-core') ~= 'started' then return nil end
    local ok, core = pcall(function() return exports['nexa-core']:GetCoreObject() end)
    return ok and core and core.Database or nil
end

local function encode(value)
    local ok, encoded = pcall(json.encode, value or {})
    return ok and encoded or '{}'
end

local function dbCall(method, sql, params, category)
    local db = coreDatabase()
    if not db or not db[method] then return nil, { code = NEXA_VEHICLE_ERRORS.databaseError } end
    return db[method](sql, params or {}, { category = category or 'vehicles.db' })
end

function NexaVehiclesDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end

    db.RegisterMigration({
        id = '110_vehicles_foundation',
        description = 'Create vehicle definitions ownership state insurance and audit tables.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_vehicle_definitions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                model VARCHAR(64) UNIQUE NOT NULL,
                label VARCHAR(128) NOT NULL,
                vehicle_type VARCHAR(32) NOT NULL,
                class VARCHAR(64) NULL,
                manufacturer VARCHAR(64) NULL,
                seats INT NULL,
                default_fuel_capacity INT NULL,
                enabled TINYINT(1) NOT NULL DEFAULT 1,
                metadata LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )]], {}, { category = 'vehicles.migration.definitions' })

            db.Query([[CREATE TABLE IF NOT EXISTS nexa_vehicles (
                id INT AUTO_INCREMENT PRIMARY KEY,
                vin VARCHAR(32) UNIQUE NOT NULL,
                plate VARCHAR(16) UNIQUE NOT NULL,
                model VARCHAR(64) NOT NULL,
                owner_type VARCHAR(32) NOT NULL,
                owner_id VARCHAR(64) NOT NULL,
                status VARCHAR(32) NOT NULL,
                garage_id VARCHAR(64) NULL,
                impound_id INT NULL,
                net_id INT NULL,
                entity_handle INT NULL,
                routing_bucket INT NULL,
                fuel INT NOT NULL DEFAULT 100000,
                mileage BIGINT NOT NULL DEFAULT 0,
                engine_health INT NOT NULL DEFAULT 1000,
                body_health INT NOT NULL DEFAULT 1000,
                tank_health INT NOT NULL DEFAULT 1000,
                damage_state VARCHAR(32) NOT NULL DEFAULT 'none',
                mods_json LONGTEXT NULL,
                state_json LONGTEXT NULL,
                metadata_json LONGTEXT NULL,
                created_by_account_id BIGINT NULL,
                created_by_character_id BIGINT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_vehicle_owner (owner_type, owner_id, status),
                INDEX idx_vehicle_status (status),
                INDEX idx_vehicle_garage (garage_id)
            )]], {}, { category = 'vehicles.migration.vehicles' })

            db.Query([[CREATE TABLE IF NOT EXISTS nexa_vehicle_insurance (
                id INT AUTO_INCREMENT PRIMARY KEY,
                vehicle_id INT NOT NULL,
                provider VARCHAR(64) NULL,
                policy_number VARCHAR(64) UNIQUE NOT NULL,
                status VARCHAR(32) NOT NULL,
                expires_at TIMESTAMP NULL,
                metadata_json LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_vehicle_insurance_vehicle (vehicle_id, status)
            )]], {}, { category = 'vehicles.migration.insurance' })

            db.Query([[CREATE TABLE IF NOT EXISTS nexa_vehicle_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                vehicle_id INT NULL,
                action VARCHAR(64) NOT NULL,
                actor_account_id BIGINT NULL,
                actor_character_id BIGINT NULL,
                before_state LONGTEXT NULL,
                after_state LONGTEXT NULL,
                reason VARCHAR(255) NULL,
                result VARCHAR(32) NOT NULL,
                error_code VARCHAR(64) NULL,
                source_resource VARCHAR(64) NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata_json LONGTEXT NULL
            )]], {}, { category = 'vehicles.migration.audit' })

            return true
        end
    })

    return db.RunMigrations()
end

function NexaVehiclesDatabase.InsertDefinition(d)
    return dbCall('Insert', 'INSERT INTO nexa_vehicle_definitions (model, label, vehicle_type, class, manufacturer, seats, default_fuel_capacity, enabled, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { d.model, d.label, d.vehicle_type, d.class, d.manufacturer, d.seats, d.default_fuel_capacity, d.enabled and 1 or 0, encode(d.metadata) }, 'vehicles.definition.insert')
end

function NexaVehiclesDatabase.GetDefinition(model)
    return dbCall('Single', 'SELECT * FROM nexa_vehicle_definitions WHERE model = ? LIMIT 1', { model }, 'vehicles.definition.get')
end

function NexaVehiclesDatabase.ListDefinitions()
    return dbCall('Query', 'SELECT * FROM nexa_vehicle_definitions ORDER BY label ASC LIMIT 500', {}, 'vehicles.definition.list')
end

function NexaVehiclesDatabase.SetDefinitionEnabled(model, enabled)
    return dbCall('Update', 'UPDATE nexa_vehicle_definitions SET enabled = ? WHERE model = ?', { enabled and 1 or 0, model }, 'vehicles.definition.enabled')
end

function NexaVehiclesDatabase.InsertVehicle(v)
    return dbCall('Insert', 'INSERT INTO nexa_vehicles (vin, plate, model, owner_type, owner_id, status, garage_id, fuel, mileage, engine_health, body_health, tank_health, damage_state, mods_json, state_json, metadata_json, created_by_account_id, created_by_character_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { v.vin, v.plate, v.model, v.owner_type, v.owner_id, v.status, v.garage_id, v.fuel, v.mileage, v.engine_health, v.body_health, v.tank_health, v.damage_state, encode(v.mods), encode(v.state), encode(v.metadata), v.created_by_account_id, v.created_by_character_id }, 'vehicles.vehicle.insert')
end

function NexaVehiclesDatabase.GetVehicle(id)
    return dbCall('Single', 'SELECT * FROM nexa_vehicles WHERE id = ? LIMIT 1', { id }, 'vehicles.vehicle.get')
end

function NexaVehiclesDatabase.GetByVin(vin)
    return dbCall('Single', 'SELECT * FROM nexa_vehicles WHERE vin = ? LIMIT 1', { vin }, 'vehicles.vehicle.vin')
end

function NexaVehiclesDatabase.GetByPlate(plate)
    return dbCall('Single', 'SELECT * FROM nexa_vehicles WHERE plate = ? LIMIT 1', { plate }, 'vehicles.vehicle.plate')
end

function NexaVehiclesDatabase.ListForOwner(ownerType, ownerId)
    return dbCall('Query', 'SELECT * FROM nexa_vehicles WHERE owner_type = ? AND owner_id = ? AND status <> ? ORDER BY id DESC', { ownerType, tostring(ownerId), NEXA_VEHICLE_STATUS.deleted }, 'vehicles.vehicle.owner')
end

function NexaVehiclesDatabase.UpdateOwnership(id, ownerType, ownerId)
    return dbCall('Update', 'UPDATE nexa_vehicles SET owner_type = ?, owner_id = ? WHERE id = ?', { ownerType, tostring(ownerId), id }, 'vehicles.vehicle.owner.update')
end

function NexaVehiclesDatabase.UpdateSpawn(id, status, netId, entityHandle, routingBucket)
    return dbCall('Update', 'UPDATE nexa_vehicles SET status = ?, net_id = ?, entity_handle = ?, routing_bucket = ? WHERE id = ?', { status, netId, entityHandle, routingBucket, id }, 'vehicles.vehicle.spawn')
end

function NexaVehiclesDatabase.SetStatus(id, status)
    return dbCall('Update', 'UPDATE nexa_vehicles SET status = ? WHERE id = ?', { status, id }, 'vehicles.vehicle.status')
end

function NexaVehiclesDatabase.UpdateState(id, s)
    return dbCall('Update', 'UPDATE nexa_vehicles SET fuel = ?, mileage = ?, engine_health = ?, body_health = ?, tank_health = ?, damage_state = ?, state_json = ? WHERE id = ?', { s.fuel, s.mileage, s.engine_health, s.body_health, s.tank_health, s.damage_state, encode(s.state), id }, 'vehicles.vehicle.state')
end

function NexaVehiclesDatabase.UpdateMods(id, mods)
    return dbCall('Update', 'UPDATE nexa_vehicles SET mods_json = ? WHERE id = ?', { encode(mods), id }, 'vehicles.vehicle.mods')
end

function NexaVehiclesDatabase.SetGarage(id, garageId, status)
    return dbCall('Update', 'UPDATE nexa_vehicles SET garage_id = ?, status = ?, net_id = NULL, entity_handle = NULL, routing_bucket = NULL WHERE id = ?', { garageId, status, id }, 'vehicles.vehicle.garage')
end

function NexaVehiclesDatabase.MarkImpounded(id, impoundId)
    return dbCall('Update', 'UPDATE nexa_vehicles SET impound_id = ?, status = ? WHERE id = ?', { impoundId, NEXA_VEHICLE_STATUS.impounded, id }, 'vehicles.vehicle.impound')
end

function NexaVehiclesDatabase.InsertInsurance(i)
    return dbCall('Insert', 'INSERT INTO nexa_vehicle_insurance (vehicle_id, provider, policy_number, status, expires_at, metadata_json) VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), ?)', { i.vehicle_id, i.provider, i.policy_number, i.status, i.expires_at, encode(i.metadata) }, 'vehicles.insurance.insert')
end

function NexaVehiclesDatabase.GetInsurance(vehicleId)
    return dbCall('Single', 'SELECT * FROM nexa_vehicle_insurance WHERE vehicle_id = ? ORDER BY id DESC LIMIT 1', { vehicleId }, 'vehicles.insurance.get')
end

function NexaVehiclesDatabase.InsertAudit(a)
    return dbCall('Insert', 'INSERT INTO nexa_vehicle_audit (vehicle_id, action, actor_account_id, actor_character_id, before_state, after_state, reason, result, error_code, source_resource, correlation_id, metadata_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { a.vehicle_id, a.action, a.actor_account_id, a.actor_character_id, a.before_state and encode(a.before_state) or nil, a.after_state and encode(a.after_state) or nil, a.reason, a.result, a.error_code, a.source_resource, a.correlation_id, encode(a.metadata) }, 'vehicles.audit.insert')
end

function NexaVehiclesDatabase.GetSchema()
    return { migration = '110_vehicles_foundation', tables = { 'nexa_vehicle_definitions', 'nexa_vehicles', 'nexa_vehicle_insurance', 'nexa_vehicle_audit' } }
end
