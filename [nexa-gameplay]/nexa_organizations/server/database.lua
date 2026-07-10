NexaOrganizationsDatabase = {}

local function coreDatabase()
    if GetResourceState('nexa-core') ~= 'started' then
        return nil
    end

    local ok, core = pcall(function()
        return exports['nexa-core']:GetCoreObject()
    end)

    return ok and core and core.Database or nil
end

local function encode(value)
    local ok, encoded = pcall(json.encode, value or {})
    return ok and encoded or '{}'
end

local function dbCall(method, sql, params, category)
    local db = coreDatabase()
    if not db or not db[method] then
        return nil, { code = NEXA_ORGANIZATION_ERRORS.databaseError, message = 'Core database unavailable.' }
    end
    return db[method](sql, params or {}, { category = category or 'organizations.db' })
end

function NexaOrganizationsDatabase.Migrate()
    local db = coreDatabase()
    if not db or not db.RegisterMigration then
        return false, 'Core database unavailable.'
    end

    db.RegisterMigration({
        id = '090_organizations_foundation',
        description = 'Create organizations ranks memberships invitations duty audit modules storages and garages.',
        transaction = false,
        up = function()
            db.Query([[
                CREATE TABLE IF NOT EXISTS nexa_organizations (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(64) UNIQUE NOT NULL,
                    label VARCHAR(128) NOT NULL,
                    organization_type VARCHAR(32) NOT NULL,
                    status VARCHAR(32) NOT NULL DEFAULT 'draft',
                    owner_character_id BIGINT NULL,
                    economy_account_id INT NULL,
                    settings LONGTEXT NULL,
                    metadata LONGTEXT NULL,
                    version INT NOT NULL DEFAULT 1,
                    created_by BIGINT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    deleted_at TIMESTAMP NULL,
                    INDEX idx_nexa_org_status (status),
                    INDEX idx_nexa_org_type (organization_type)
                )
            ]], {}, { category = 'organizations.migration.organizations' })

            db.Query([[
                CREATE TABLE IF NOT EXISTS nexa_organization_ranks (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    organization_id INT NOT NULL,
                    rank_key VARCHAR(64) NOT NULL,
                    label VARCHAR(128) NOT NULL,
                    position INT NOT NULL,
                    is_leadership TINYINT(1) NOT NULL DEFAULT 0,
                    is_owner_rank TINYINT(1) NOT NULL DEFAULT 0,
                    permissions LONGTEXT NULL,
                    salary_policy LONGTEXT NULL,
                    metadata LONGTEXT NULL,
                    version INT NOT NULL DEFAULT 1,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    UNIQUE KEY uq_nexa_org_rank_key (organization_id, rank_key),
                    UNIQUE KEY uq_nexa_org_rank_position (organization_id, position),
                    INDEX idx_nexa_org_rank_owner (organization_id, is_owner_rank)
                )
            ]], {}, { category = 'organizations.migration.ranks' })

            db.Query([[
                CREATE TABLE IF NOT EXISTS nexa_organization_members (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    organization_id INT NOT NULL,
                    character_id BIGINT NOT NULL,
                    rank_id INT NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    joined_at TIMESTAMP NULL,
                    left_at TIMESTAMP NULL,
                    invited_by BIGINT NULL,
                    updated_by BIGINT NULL,
                    metadata LONGTEXT NULL,
                    version INT NOT NULL DEFAULT 1,
                    UNIQUE KEY uq_nexa_org_member_active (character_id, status),
                    INDEX idx_nexa_org_member_org (organization_id),
                    INDEX idx_nexa_org_member_character (character_id)
                )
            ]], {}, { category = 'organizations.migration.members' })

            db.Query([[
                CREATE TABLE IF NOT EXISTS nexa_organization_invitations (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    organization_id INT NOT NULL,
                    target_character_id BIGINT NOT NULL,
                    rank_id INT NOT NULL,
                    invited_by_character_id BIGINT NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    expires_at TIMESTAMP NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    responded_at TIMESTAMP NULL,
                    metadata LONGTEXT NULL,
                    UNIQUE KEY uq_nexa_org_invitation_pending (organization_id, target_character_id, status)
                )
            ]], {}, { category = 'organizations.migration.invitations' })

            db.Query([[
                CREATE TABLE IF NOT EXISTS nexa_job_duty_sessions (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    character_id BIGINT NOT NULL,
                    organization_id INT NOT NULL,
                    rank_id INT NOT NULL,
                    status VARCHAR(32) NOT NULL,
                    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    ended_at TIMESTAMP NULL,
                    start_reason VARCHAR(255) NULL,
                    end_reason VARCHAR(255) NULL,
                    source INT NULL,
                    metadata LONGTEXT NULL,
                    INDEX idx_nexa_duty_character (character_id),
                    INDEX idx_nexa_duty_org_status (organization_id, status)
                )
            ]], {}, { category = 'organizations.migration.duty' })

            db.Query([[
                CREATE TABLE IF NOT EXISTS nexa_organization_audit (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    organization_id INT NULL,
                    action VARCHAR(64) NOT NULL,
                    actor_account_id BIGINT NULL,
                    actor_character_id BIGINT NULL,
                    target_character_id BIGINT NULL,
                    rank_id INT NULL,
                    before_state LONGTEXT NULL,
                    after_state LONGTEXT NULL,
                    reason VARCHAR(255) NULL,
                    result VARCHAR(32) NOT NULL,
                    error_code VARCHAR(64) NULL,
                    source_resource VARCHAR(64) NULL,
                    correlation_id VARCHAR(128) NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    metadata LONGTEXT NULL,
                    INDEX idx_nexa_org_audit_org (organization_id),
                    INDEX idx_nexa_org_audit_action (action)
                )
            ]], {}, { category = 'organizations.migration.audit' })

            db.Query([[
                CREATE TABLE IF NOT EXISTS nexa_organization_modules (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    organization_id INT NOT NULL,
                    module_name VARCHAR(64) NOT NULL,
                    enabled TINYINT(1) NOT NULL DEFAULT 1,
                    config LONGTEXT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    UNIQUE KEY uq_nexa_org_module (organization_id, module_name)
                )
            ]], {}, { category = 'organizations.migration.modules' })

            db.Query([[
                CREATE TABLE IF NOT EXISTS nexa_organization_storages (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    organization_id INT NOT NULL,
                    storage_key VARCHAR(64) NOT NULL,
                    storage_type VARCHAR(32) NOT NULL,
                    inventory_id INT NULL,
                    duty_required TINYINT(1) NOT NULL DEFAULT 0,
                    permissions LONGTEXT NULL,
                    metadata LONGTEXT NULL,
                    status VARCHAR(32) NOT NULL DEFAULT 'active',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY uq_nexa_org_storage (organization_id, storage_key)
                )
            ]], {}, { category = 'organizations.migration.storages' })

            db.Query([[
                CREATE TABLE IF NOT EXISTS nexa_organization_garages (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    organization_id INT NOT NULL,
                    garage_key VARCHAR(64) NOT NULL,
                    garage_type VARCHAR(32) NOT NULL,
                    position LONGTEXT NULL,
                    spawn_points LONGTEXT NULL,
                    allowed_ranks LONGTEXT NULL,
                    duty_required TINYINT(1) NOT NULL DEFAULT 0,
                    vehicle_classes LONGTEXT NULL,
                    status VARCHAR(32) NOT NULL DEFAULT 'active',
                    metadata LONGTEXT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY uq_nexa_org_garage (organization_id, garage_key)
                )
            ]], {}, { category = 'organizations.migration.garages' })

            return true
        end
    })

    return db.RunMigrations()
end

function NexaOrganizationsDatabase.InsertOrganization(payload)
    return dbCall('Insert', [[
        INSERT INTO nexa_organizations (name, label, organization_type, status, owner_character_id, economy_account_id, settings, metadata, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { payload.name, payload.label, payload.organization_type, payload.status, payload.owner_character_id, payload.economy_account_id, encode(payload.settings), encode(payload.metadata), payload.created_by }, 'organizations.insert')
end

function NexaOrganizationsDatabase.GetOrganization(id)
    return dbCall('Single', 'SELECT * FROM nexa_organizations WHERE id = ? AND deleted_at IS NULL LIMIT 1', { id }, 'organizations.get')
end

function NexaOrganizationsDatabase.GetOrganizationByName(name)
    return dbCall('Single', 'SELECT * FROM nexa_organizations WHERE name = ? AND deleted_at IS NULL LIMIT 1', { name }, 'organizations.get_name')
end

function NexaOrganizationsDatabase.ListOrganizations()
    return dbCall('Query', 'SELECT * FROM nexa_organizations WHERE deleted_at IS NULL ORDER BY id ASC', {}, 'organizations.list')
end

function NexaOrganizationsDatabase.UpdateOrganization(id, changes)
    return dbCall('Update', 'UPDATE nexa_organizations SET label = COALESCE(?, label), status = COALESCE(?, status), economy_account_id = COALESCE(?, economy_account_id), settings = COALESCE(?, settings), metadata = COALESCE(?, metadata), version = version + 1 WHERE id = ?', { changes.label, changes.status, changes.economy_account_id, changes.settings and encode(changes.settings) or nil, changes.metadata and encode(changes.metadata) or nil, id }, 'organizations.update')
end

function NexaOrganizationsDatabase.SoftDeleteOrganization(id)
    return dbCall('Update', 'UPDATE nexa_organizations SET status = ?, deleted_at = CURRENT_TIMESTAMP, version = version + 1 WHERE id = ?', { NEXA_ORGANIZATION_STATUS.deleted, id }, 'organizations.delete')
end

function NexaOrganizationsDatabase.InsertRank(payload)
    return dbCall('Insert', [[
        INSERT INTO nexa_organization_ranks (organization_id, rank_key, label, position, is_leadership, is_owner_rank, permissions, salary_policy, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { payload.organization_id, payload.rank_key, payload.label, payload.position, payload.is_leadership and 1 or 0, payload.is_owner_rank and 1 or 0, encode(payload.permissions), encode(payload.salary_policy), encode(payload.metadata) }, 'organizations.ranks.insert')
end

function NexaOrganizationsDatabase.GetRank(rankId)
    return dbCall('Single', 'SELECT * FROM nexa_organization_ranks WHERE id = ? LIMIT 1', { rankId }, 'organizations.ranks.get')
end

function NexaOrganizationsDatabase.ListRanks(organizationId)
    return dbCall('Query', 'SELECT * FROM nexa_organization_ranks WHERE organization_id = ? ORDER BY position ASC', { organizationId }, 'organizations.ranks.list')
end

function NexaOrganizationsDatabase.UpdateRank(rankId, changes)
    return dbCall('Update', 'UPDATE nexa_organization_ranks SET label = COALESCE(?, label), position = COALESCE(?, position), is_leadership = COALESCE(?, is_leadership), permissions = COALESCE(?, permissions), version = version + 1 WHERE id = ?', { changes.label, changes.position, changes.is_leadership, changes.permissions and encode(changes.permissions) or nil, rankId }, 'organizations.ranks.update')
end

function NexaOrganizationsDatabase.InsertMember(payload)
    return dbCall('Insert', [[
        INSERT INTO nexa_organization_members (organization_id, character_id, rank_id, status, joined_at, invited_by, updated_by, metadata)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP, ?, ?, ?)
    ]], { payload.organization_id, payload.character_id, payload.rank_id, payload.status, payload.invited_by, payload.updated_by, encode(payload.metadata) }, 'organizations.members.insert')
end

function NexaOrganizationsDatabase.GetActiveMemberByCharacter(characterId)
    return dbCall('Single', 'SELECT * FROM nexa_organization_members WHERE character_id = ? AND status = ? LIMIT 1', { characterId, NEXA_ORGANIZATION_MEMBER_STATUS.active }, 'organizations.members.get_character')
end

function NexaOrganizationsDatabase.GetMember(organizationId, characterId)
    return dbCall('Single', 'SELECT * FROM nexa_organization_members WHERE organization_id = ? AND character_id = ? AND status = ? LIMIT 1', { organizationId, characterId, NEXA_ORGANIZATION_MEMBER_STATUS.active }, 'organizations.members.get')
end

function NexaOrganizationsDatabase.ListMembers(organizationId)
    return dbCall('Query', 'SELECT * FROM nexa_organization_members WHERE organization_id = ? ORDER BY id ASC', { organizationId }, 'organizations.members.list')
end

function NexaOrganizationsDatabase.UpdateMemberRank(organizationId, characterId, rankId, actorCharacterId)
    return dbCall('Update', 'UPDATE nexa_organization_members SET rank_id = ?, updated_by = ?, version = version + 1 WHERE organization_id = ? AND character_id = ? AND status = ?', { rankId, actorCharacterId, organizationId, characterId, NEXA_ORGANIZATION_MEMBER_STATUS.active }, 'organizations.members.rank')
end

function NexaOrganizationsDatabase.UpdateMemberStatus(organizationId, characterId, status, actorCharacterId)
    return dbCall('Update', 'UPDATE nexa_organization_members SET status = ?, left_at = CURRENT_TIMESTAMP, updated_by = ?, version = version + 1 WHERE organization_id = ? AND character_id = ?', { status, actorCharacterId, organizationId, characterId }, 'organizations.members.status')
end

function NexaOrganizationsDatabase.InsertInvitation(payload)
    return dbCall('Insert', [[
        INSERT INTO nexa_organization_invitations (organization_id, target_character_id, rank_id, invited_by_character_id, status, expires_at, metadata)
        VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?), ?)
    ]], { payload.organization_id, payload.target_character_id, payload.rank_id, payload.invited_by_character_id, payload.status, payload.expires_at, encode(payload.metadata) }, 'organizations.invitations.insert')
end

function NexaOrganizationsDatabase.GetInvitation(id)
    return dbCall('Single', 'SELECT * FROM nexa_organization_invitations WHERE id = ? LIMIT 1', { id }, 'organizations.invitations.get')
end

function NexaOrganizationsDatabase.UpdateInvitationStatus(id, status)
    return dbCall('Update', 'UPDATE nexa_organization_invitations SET status = ?, responded_at = CURRENT_TIMESTAMP WHERE id = ?', { status, id }, 'organizations.invitations.status')
end

function NexaOrganizationsDatabase.InsertModule(payload)
    return dbCall('Insert', 'INSERT INTO nexa_organization_modules (organization_id, module_name, enabled, config) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE enabled = VALUES(enabled), config = VALUES(config)', { payload.organization_id, payload.module_name, payload.enabled and 1 or 0, encode(payload.config) }, 'organizations.modules.upsert')
end

function NexaOrganizationsDatabase.ListModules(organizationId)
    return dbCall('Query', 'SELECT * FROM nexa_organization_modules WHERE organization_id = ?', { organizationId }, 'organizations.modules.list')
end

function NexaOrganizationsDatabase.InsertStorage(payload)
    return dbCall('Insert', 'INSERT INTO nexa_organization_storages (organization_id, storage_key, storage_type, inventory_id, duty_required, permissions, metadata) VALUES (?, ?, ?, ?, ?, ?, ?)', { payload.organization_id, payload.storage_key, payload.storage_type, payload.inventory_id, payload.duty_required and 1 or 0, encode(payload.permissions), encode(payload.metadata) }, 'organizations.storages.insert')
end

function NexaOrganizationsDatabase.InsertGarage(payload)
    return dbCall('Insert', 'INSERT INTO nexa_organization_garages (organization_id, garage_key, garage_type, position, spawn_points, allowed_ranks, duty_required, vehicle_classes, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { payload.organization_id, payload.garage_key, payload.garage_type, encode(payload.position), encode(payload.spawn_points), encode(payload.allowed_ranks), payload.duty_required and 1 or 0, encode(payload.vehicle_classes), encode(payload.metadata) }, 'organizations.garages.insert')
end

function NexaOrganizationsDatabase.InsertAudit(payload)
    return dbCall('Insert', [[
        INSERT INTO nexa_organization_audit (organization_id, action, actor_account_id, actor_character_id, target_character_id, rank_id, before_state, after_state, reason, result, error_code, source_resource, correlation_id, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { payload.organization_id, payload.action, payload.actor_account_id, payload.actor_character_id, payload.target_character_id, payload.rank_id, payload.before_state and encode(payload.before_state) or nil, payload.after_state and encode(payload.after_state) or nil, payload.reason, payload.result, payload.error_code, payload.source_resource, payload.correlation_id, encode(payload.metadata) }, 'organizations.audit.insert')
end

function NexaOrganizationsDatabase.GetSchema()
    return {
        migration = '090_organizations_foundation',
        tables = {
            'nexa_organizations',
            'nexa_organization_ranks',
            'nexa_organization_members',
            'nexa_organization_invitations',
            'nexa_job_duty_sessions',
            'nexa_organization_audit',
            'nexa_organization_modules',
            'nexa_organization_storages',
            'nexa_organization_garages'
        }
    }
end
