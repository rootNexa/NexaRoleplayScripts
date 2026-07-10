NexaPropertiesDatabase = {}

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
    if not db or not db[method] then return nil, { code = NEXA_PROPERTY_ERRORS.databaseError } end
    return db[method](sql, params or {}, { category = category or 'properties.db' })
end

function NexaPropertiesDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then return false, 'Core database unavailable.' end
    db.RegisterMigration({
        id = '120_properties_foundation',
        description = 'Create property definitions instances ownership leases residents furniture and audit.',
        transaction = false,
        up = function()
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_definitions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_key VARCHAR(64) UNIQUE NOT NULL,
                label VARCHAR(128) NOT NULL,
                property_type VARCHAR(32) NOT NULL,
                status VARCHAR(32) NOT NULL,
                purchase_price BIGINT NOT NULL DEFAULT 0,
                rent_amount BIGINT NOT NULL DEFAULT 0,
                rent_interval_seconds INT NOT NULL DEFAULT 604800,
                entrance LONGTEXT NULL,
                exterior LONGTEXT NULL,
                interior_definition_id INT NULL,
                garage_definition_id VARCHAR(64) NULL,
                storage_configuration LONGTEXT NULL,
                security_configuration LONGTEXT NULL,
                settings LONGTEXT NULL,
                metadata LONGTEXT NULL,
                version INT NOT NULL DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                deleted_at TIMESTAMP NULL,
                INDEX idx_property_definition_status (property_type, status)
            )]], {}, { category = 'properties.migration.definitions' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_properties (
                id INT AUTO_INCREMENT PRIMARY KEY,
                definition_id INT NOT NULL,
                property_number VARCHAR(32) UNIQUE NOT NULL,
                owner_type VARCHAR(32) NOT NULL,
                owner_id VARCHAR(64) NOT NULL,
                ownership_status VARCHAR(32) NOT NULL,
                lease_status VARCHAR(32) NULL,
                interior_instance_id INT NULL,
                routing_bucket INT UNIQUE NULL,
                primary_storage_id VARCHAR(128) NULL,
                garage_id VARCHAR(64) NULL,
                security_status VARCHAR(32) NULL,
                version INT NOT NULL DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                deleted_at TIMESTAMP NULL,
                INDEX idx_property_owner (owner_type, owner_id, ownership_status)
            )]], {}, { category = 'properties.migration.properties' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_ownership_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NOT NULL,
                owner_type VARCHAR(32) NOT NULL,
                owner_id VARCHAR(64) NOT NULL,
                ownership_type VARCHAR(32) NOT NULL,
                starts_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                ends_at TIMESTAMP NULL,
                reason VARCHAR(255) NULL,
                transaction_id VARCHAR(64) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL,
                INDEX idx_property_owner_history (property_id, ends_at)
            )]], {}, { category = 'properties.migration.ownership' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_leases (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NOT NULL,
                tenant_character_id BIGINT NOT NULL,
                status VARCHAR(32) NOT NULL,
                rent_amount BIGINT NOT NULL,
                interval_seconds INT NOT NULL,
                starts_at TIMESTAMP NULL,
                next_due_at TIMESTAMP NULL,
                ends_at TIMESTAMP NULL,
                deposit_amount BIGINT NOT NULL DEFAULT 0,
                economy_account_id INT NULL,
                created_by BIGINT NULL,
                terminated_by BIGINT NULL,
                termination_reason VARCHAR(255) NULL,
                metadata LONGTEXT NULL,
                INDEX idx_property_lease (property_id, status),
                INDEX idx_character_lease (tenant_character_id, status)
            )]], {}, { category = 'properties.migration.leases' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_residents (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NOT NULL,
                character_id BIGINT NOT NULL,
                resident_type VARCHAR(32) NOT NULL,
                status VARCHAR(32) NOT NULL,
                permissions LONGTEXT NULL,
                invited_by BIGINT NULL,
                joined_at TIMESTAMP NULL,
                left_at TIMESTAMP NULL,
                metadata LONGTEXT NULL,
                UNIQUE KEY uq_active_property_resident (property_id, character_id, status)
            )]], {}, { category = 'properties.migration.residents' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_furniture (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NOT NULL,
                model VARCHAR(64) NOT NULL,
                position LONGTEXT NOT NULL,
                rotation LONGTEXT NOT NULL,
                scale LONGTEXT NULL,
                state LONGTEXT NULL,
                placed_by BIGINT NULL,
                status VARCHAR(32) NOT NULL,
                metadata LONGTEXT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_property_furniture (property_id, status)
            )]], {}, { category = 'properties.migration.furniture' })
            db.Query([[CREATE TABLE IF NOT EXISTS nexa_property_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                property_id INT NULL,
                action VARCHAR(64) NOT NULL,
                actor_account_id BIGINT NULL,
                actor_character_id BIGINT NULL,
                target_character_id BIGINT NULL,
                before_state LONGTEXT NULL,
                after_state LONGTEXT NULL,
                reason VARCHAR(255) NULL,
                result VARCHAR(32) NOT NULL,
                error_code VARCHAR(64) NULL,
                source_resource VARCHAR(64) NULL,
                correlation_id VARCHAR(128) NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL
            )]], {}, { category = 'properties.migration.audit' })
            return true
        end
    })
    return db.RunMigrations()
end

function NexaPropertiesDatabase.InsertDefinition(d) return dbCall('Insert', 'INSERT INTO nexa_property_definitions (property_key, label, property_type, status, purchase_price, rent_amount, rent_interval_seconds, entrance, exterior, interior_definition_id, garage_definition_id, storage_configuration, security_configuration, settings, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { d.property_key, d.label, d.property_type, d.status, d.purchase_price, d.rent_amount, d.rent_interval_seconds, encode(d.entrance), encode(d.exterior), d.interior_definition_id, d.garage_definition_id, encode(d.storage_configuration), encode(d.security_configuration), encode(d.settings), encode(d.metadata) }, 'properties.definition.insert') end
function NexaPropertiesDatabase.GetDefinition(idOrKey) local id = tonumber(idOrKey); if id then return dbCall('Single', 'SELECT * FROM nexa_property_definitions WHERE id = ? AND deleted_at IS NULL LIMIT 1', { id }, 'properties.definition.get') end; return dbCall('Single', 'SELECT * FROM nexa_property_definitions WHERE property_key = ? AND deleted_at IS NULL LIMIT 1', { tostring(idOrKey) }, 'properties.definition.key') end
function NexaPropertiesDatabase.ListDefinitions() return dbCall('Query', 'SELECT * FROM nexa_property_definitions WHERE deleted_at IS NULL ORDER BY id DESC LIMIT 500', {}, 'properties.definition.list') end
function NexaPropertiesDatabase.UpdateDefinitionStatus(id, status) return dbCall('Update', 'UPDATE nexa_property_definitions SET status = ?, version = version + 1 WHERE id = ?', { status, id }, 'properties.definition.status') end
function NexaPropertiesDatabase.InsertProperty(p) return dbCall('Insert', 'INSERT INTO nexa_properties (definition_id, property_number, owner_type, owner_id, ownership_status, lease_status, primary_storage_id, garage_id, security_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { p.definition_id, p.property_number, p.owner_type, p.owner_id, p.ownership_status, p.lease_status, p.primary_storage_id, p.garage_id, p.security_status }, 'properties.property.insert') end
function NexaPropertiesDatabase.GetProperty(id) return dbCall('Single', 'SELECT * FROM nexa_properties WHERE id = ? AND deleted_at IS NULL LIMIT 1', { id }, 'properties.property.get') end
function NexaPropertiesDatabase.GetPropertyByNumber(number) return dbCall('Single', 'SELECT * FROM nexa_properties WHERE property_number = ? AND deleted_at IS NULL LIMIT 1', { number }, 'properties.property.number') end
function NexaPropertiesDatabase.ListProperties() return dbCall('Query', 'SELECT * FROM nexa_properties WHERE deleted_at IS NULL ORDER BY id DESC LIMIT 500', {}, 'properties.property.list') end
function NexaPropertiesDatabase.ListForOwner(ownerType, ownerId) return dbCall('Query', 'SELECT * FROM nexa_properties WHERE owner_type = ? AND owner_id = ? AND deleted_at IS NULL ORDER BY id DESC', { ownerType, tostring(ownerId) }, 'properties.property.owner') end
function NexaPropertiesDatabase.UpdatePropertyOwner(id, ownerType, ownerId, status) return dbCall('Update', 'UPDATE nexa_properties SET owner_type = ?, owner_id = ?, ownership_status = ?, version = version + 1 WHERE id = ?', { ownerType, tostring(ownerId), status, id }, 'properties.property.owner.update') end
function NexaPropertiesDatabase.UpdatePropertyStatus(id, status) return dbCall('Update', 'UPDATE nexa_properties SET ownership_status = ?, version = version + 1 WHERE id = ?', { status, id }, 'properties.property.status') end
function NexaPropertiesDatabase.SoftDeleteProperty(id) return dbCall('Update', 'UPDATE nexa_properties SET deleted_at = CURRENT_TIMESTAMP, ownership_status = ? WHERE id = ?', { NEXA_PROPERTY_OWNERSHIP_STATUS.archived, id }, 'properties.property.delete') end
function NexaPropertiesDatabase.InsertOwnershipHistory(h) return dbCall('Insert', 'INSERT INTO nexa_property_ownership_history (property_id, owner_type, owner_id, ownership_type, reason, transaction_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)', { h.property_id, h.owner_type, h.owner_id, h.ownership_type, h.reason, h.transaction_id, encode(h.metadata) }, 'properties.ownership.insert') end
function NexaPropertiesDatabase.GetActiveLease(propertyId) return dbCall('Single', 'SELECT * FROM nexa_property_leases WHERE property_id = ? AND status = ? LIMIT 1', { propertyId, NEXA_PROPERTY_LEASE_STATUS.active }, 'properties.lease.active') end
function NexaPropertiesDatabase.GetLease(id) return dbCall('Single', 'SELECT * FROM nexa_property_leases WHERE id = ? LIMIT 1', { id }, 'properties.lease.get') end
function NexaPropertiesDatabase.GetCharacterLease(characterId) return dbCall('Single', 'SELECT * FROM nexa_property_leases WHERE tenant_character_id = ? AND status IN (?, ?) ORDER BY id DESC LIMIT 1', { characterId, NEXA_PROPERTY_LEASE_STATUS.active, NEXA_PROPERTY_LEASE_STATUS.overdue }, 'properties.lease.character') end
function NexaPropertiesDatabase.InsertLease(l) return dbCall('Insert', 'INSERT INTO nexa_property_leases (property_id, tenant_character_id, status, rent_amount, interval_seconds, starts_at, next_due_at, deposit_amount, economy_account_id, created_by, metadata) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP, FROM_UNIXTIME(?), ?, ?, ?, ?)', { l.property_id, l.tenant_character_id, l.status, l.rent_amount, l.interval_seconds, l.next_due_at, l.deposit_amount, l.economy_account_id, l.created_by, encode(l.metadata) }, 'properties.lease.insert') end
function NexaPropertiesDatabase.UpdateLeaseStatus(id, status, reason) return dbCall('Update', 'UPDATE nexa_property_leases SET status = ?, termination_reason = ?, ends_at = CASE WHEN ? IN (?, ?) THEN CURRENT_TIMESTAMP ELSE ends_at END WHERE id = ?', { status, reason, status, NEXA_PROPERTY_LEASE_STATUS.terminated, NEXA_PROPERTY_LEASE_STATUS.evicted, id }, 'properties.lease.status') end
function NexaPropertiesDatabase.MarkRentPaid(id, nextDueAt) return dbCall('Update', 'UPDATE nexa_property_leases SET status = ?, next_due_at = FROM_UNIXTIME(?) WHERE id = ?', { NEXA_PROPERTY_LEASE_STATUS.active, nextDueAt, id }, 'properties.rent.paid') end
function NexaPropertiesDatabase.ListResidents(propertyId) return dbCall('Query', 'SELECT * FROM nexa_property_residents WHERE property_id = ? AND status IN (?, ?) ORDER BY id ASC', { propertyId, NEXA_PROPERTY_RESIDENT_STATUS.invited, NEXA_PROPERTY_RESIDENT_STATUS.active }, 'properties.residents.list') end
function NexaPropertiesDatabase.GetResident(propertyId, characterId) return dbCall('Single', 'SELECT * FROM nexa_property_residents WHERE property_id = ? AND character_id = ? AND status IN (?, ?) LIMIT 1', { propertyId, characterId, NEXA_PROPERTY_RESIDENT_STATUS.invited, NEXA_PROPERTY_RESIDENT_STATUS.active }, 'properties.residents.get') end
function NexaPropertiesDatabase.InsertResident(r) return dbCall('Insert', 'INSERT INTO nexa_property_residents (property_id, character_id, resident_type, status, permissions, invited_by, joined_at, metadata) VALUES (?, ?, ?, ?, ?, ?, CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE NULL END, ?)', { r.property_id, r.character_id, r.resident_type, r.status, encode(r.permissions), r.invited_by, r.status, NEXA_PROPERTY_RESIDENT_STATUS.active, encode(r.metadata) }, 'properties.residents.insert') end
function NexaPropertiesDatabase.UpdateResidentStatus(id, status) return dbCall('Update', 'UPDATE nexa_property_residents SET status = ?, joined_at = CASE WHEN ? = ? THEN CURRENT_TIMESTAMP ELSE joined_at END, left_at = CASE WHEN ? IN (?, ?) THEN CURRENT_TIMESTAMP ELSE left_at END WHERE id = ?', { status, status, NEXA_PROPERTY_RESIDENT_STATUS.active, status, NEXA_PROPERTY_RESIDENT_STATUS.removed, NEXA_PROPERTY_RESIDENT_STATUS.expired, id }, 'properties.residents.status') end
function NexaPropertiesDatabase.UpdateResidentPermissions(id, permissions) return dbCall('Update', 'UPDATE nexa_property_residents SET permissions = ? WHERE id = ?', { encode(permissions), id }, 'properties.residents.permissions') end
function NexaPropertiesDatabase.InsertFurniture(f) return dbCall('Insert', 'INSERT INTO nexa_property_furniture (property_id, model, position, rotation, scale, state, placed_by, status, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { f.property_id, f.model, encode(f.position), encode(f.rotation), encode(f.scale), encode(f.state), f.placed_by, f.status, encode(f.metadata) }, 'properties.furniture.insert') end
function NexaPropertiesDatabase.ListFurniture(propertyId) return dbCall('Query', 'SELECT * FROM nexa_property_furniture WHERE property_id = ? AND status = ? ORDER BY id ASC', { propertyId, 'active' }, 'properties.furniture.list') end
function NexaPropertiesDatabase.UpdateFurniture(id, transform) return dbCall('Update', 'UPDATE nexa_property_furniture SET position = ?, rotation = ?, scale = ? WHERE id = ?', { encode(transform.position), encode(transform.rotation), encode(transform.scale), id }, 'properties.furniture.update') end
function NexaPropertiesDatabase.RemoveFurniture(id) return dbCall('Update', 'UPDATE nexa_property_furniture SET status = ? WHERE id = ?', { 'removed', id }, 'properties.furniture.remove') end
function NexaPropertiesDatabase.InsertAudit(a) return dbCall('Insert', 'INSERT INTO nexa_property_audit (property_id, action, actor_account_id, actor_character_id, target_character_id, before_state, after_state, reason, result, error_code, source_resource, correlation_id, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { a.property_id, a.action, a.actor_account_id, a.actor_character_id, a.target_character_id, a.before_state and encode(a.before_state) or nil, a.after_state and encode(a.after_state) or nil, a.reason, a.result, a.error_code, a.source_resource, a.correlation_id, encode(a.metadata) }, 'properties.audit.insert') end
function NexaPropertiesDatabase.GetSchema() return { migration = '120_properties_foundation', tables = { 'nexa_property_definitions', 'nexa_properties', 'nexa_property_ownership_history', 'nexa_property_leases', 'nexa_property_residents', 'nexa_property_furniture', 'nexa_property_audit' } } end
