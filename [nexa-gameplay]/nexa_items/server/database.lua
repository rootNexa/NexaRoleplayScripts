NexaItemsDatabase = {}

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then
        return nil
    end

    local ok, core = pcall(function()
        return exports['nexa-core']:GetCoreObject()
    end)

    return ok and core or nil
end

local function database()
    local core = getCore()
    return core and core.Database or nil
end

local function call(method, sql, params, options)
    local db = database()

    if not db or not db[method] then
        return nil, {
            code = NEXA_ITEMS_ERRORS.databaseError,
            message = 'Core database is not ready.'
        }
    end

    return db[method](sql, params or {}, options or { category = 'items' })
end

function NexaItemsDatabase.Migrate()
    local db = database()

    if not db or not db.RegisterMigration then
        return false, 'Core database is not ready.'
    end

    db.RegisterMigration({
        id = '070_item_registry_foundation',
        description = 'Create item registry, version, action, asset and audit tables',
        transaction = false,
        statements = {
            [[CREATE TABLE IF NOT EXISTS nexa_item_definitions (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                name VARCHAR(64) NOT NULL,
                label VARCHAR(128) NOT NULL,
                description TEXT NULL,
                item_type VARCHAR(32) NOT NULL,
                weight INT NOT NULL DEFAULT 0,
                stackable TINYINT(1) NOT NULL DEFAULT 1,
                max_stack INT NOT NULL DEFAULT 1,
                usable TINYINT(1) NOT NULL DEFAULT 0,
                quickslot_allowed TINYINT(1) NOT NULL DEFAULT 0,
                droppable TINYINT(1) NOT NULL DEFAULT 1,
                tradeable TINYINT(1) NOT NULL DEFAULT 1,
                destroyable TINYINT(1) NOT NULL DEFAULT 1,
                container_allowed TINYINT(1) NOT NULL DEFAULT 0,
                metadata_schema LONGTEXT NULL,
                default_metadata LONGTEXT NULL,
                durability_config LONGTEXT NULL,
                expiration_config LONGTEXT NULL,
                image_reference TEXT NULL,
                status VARCHAR(32) NOT NULL DEFAULT 'draft',
                version INT NOT NULL DEFAULT 1,
                created_by BIGINT UNSIGNED NULL,
                updated_by BIGINT UNSIGNED NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                published_at TIMESTAMP NULL,
                deleted_at TIMESTAMP NULL,
                PRIMARY KEY (id),
                UNIQUE KEY uq_nexa_item_definitions_name (name),
                KEY idx_nexa_item_definitions_type (item_type),
                KEY idx_nexa_item_definitions_status (status),
                KEY idx_nexa_item_definitions_version (version)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
            [[CREATE TABLE IF NOT EXISTS nexa_item_definition_versions (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                item_definition_id BIGINT UNSIGNED NOT NULL,
                version INT NOT NULL,
                snapshot LONGTEXT NOT NULL,
                change_reason VARCHAR(128) NULL,
                created_by BIGINT UNSIGNED NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_nexa_item_definition_versions (item_definition_id, version),
                CONSTRAINT fk_nexa_item_definition_versions_definition
                    FOREIGN KEY (item_definition_id)
                    REFERENCES nexa_item_definitions (id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
            [[CREATE TABLE IF NOT EXISTS nexa_item_actions (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                item_definition_id BIGINT UNSIGNED NOT NULL,
                action_name VARCHAR(64) NOT NULL,
                handler_name VARCHAR(64) NOT NULL,
                side VARCHAR(16) NOT NULL DEFAULT 'server',
                priority INT NOT NULL DEFAULT 0,
                cooldown_ms INT NOT NULL DEFAULT 0,
                requires_active_player TINYINT(1) NOT NULL DEFAULT 1,
                requires_quickslot TINYINT(1) NOT NULL DEFAULT 0,
                configuration LONGTEXT NULL,
                enabled TINYINT(1) NOT NULL DEFAULT 1,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_nexa_item_actions_definition (item_definition_id),
                KEY idx_nexa_item_actions_handler (handler_name),
                CONSTRAINT fk_nexa_item_actions_definition
                    FOREIGN KEY (item_definition_id)
                    REFERENCES nexa_item_definitions (id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
            [[CREATE TABLE IF NOT EXISTS nexa_item_assets (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                item_definition_id BIGINT UNSIGNED NOT NULL,
                asset_type VARCHAR(32) NOT NULL,
                source_url TEXT NULL,
                local_path TEXT NULL,
                checksum VARCHAR(128) NULL,
                mime_type VARCHAR(64) NULL,
                size_bytes INT NULL,
                status VARCHAR(32) NOT NULL DEFAULT 'pending',
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_nexa_item_assets_definition (item_definition_id),
                KEY idx_nexa_item_assets_status (status),
                CONSTRAINT fk_nexa_item_assets_definition
                    FOREIGN KEY (item_definition_id)
                    REFERENCES nexa_item_definitions (id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
            [[CREATE TABLE IF NOT EXISTS nexa_item_audit (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                action VARCHAR(64) NOT NULL,
                actor_account_id BIGINT UNSIGNED NULL,
                item_name VARCHAR(64) NULL,
                old_version INT NULL,
                new_version INT NULL,
                before_state LONGTEXT NULL,
                after_state LONGTEXT NULL,
                reason VARCHAR(128) NULL,
                result VARCHAR(32) NOT NULL,
                error_code VARCHAR(64) NULL,
                correlation_id VARCHAR(96) NULL,
                source_resource VARCHAR(64) NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_nexa_item_audit_item (item_name),
                KEY idx_nexa_item_audit_action (action),
                KEY idx_nexa_item_audit_correlation (correlation_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
        }
    })

    return db.RunMigrations()
end

function NexaItemsDatabase.InsertDefinition(payload)
    return call('Insert', [[
        INSERT INTO nexa_item_definitions (
            name, label, description, item_type, weight, stackable, max_stack, usable, quickslot_allowed,
            droppable, tradeable, destroyable, container_allowed, metadata_schema, default_metadata,
            durability_config, expiration_config, image_reference, status, version, created_by, updated_by, published_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.name,
        payload.label,
        payload.description,
        payload.item_type,
        payload.weight,
        payload.stackable and 1 or 0,
        payload.max_stack,
        payload.usable and 1 or 0,
        payload.quickslot_allowed and 1 or 0,
        payload.droppable and 1 or 0,
        payload.tradeable and 1 or 0,
        payload.destroyable and 1 or 0,
        payload.container_allowed and 1 or 0,
        payload.metadata_schema,
        payload.default_metadata,
        payload.durability_config,
        payload.expiration_config,
        payload.image_reference,
        payload.status,
        payload.version or 1,
        payload.created_by,
        payload.updated_by,
        payload.published_at
    }, { category = 'items.definition.insert' })
end

function NexaItemsDatabase.GetDefinitionByName(name)
    return call('Single', 'SELECT * FROM nexa_item_definitions WHERE name = ? AND status <> ? LIMIT 1', {
        name,
        NEXA_ITEM_STATUS.deleted
    }, { category = 'items.definition.get' })
end

function NexaItemsDatabase.GetDefinitionById(id)
    return call('Single', 'SELECT * FROM nexa_item_definitions WHERE id = ? LIMIT 1', { id }, {
        category = 'items.definition.get_id'
    })
end

function NexaItemsDatabase.ListDefinitions(filter)
    filter = filter or {}
    local sql = 'SELECT * FROM nexa_item_definitions WHERE deleted_at IS NULL'
    local params = {}

    if filter.status then
        sql = sql .. ' AND status = ?'
        params[#params + 1] = filter.status
    end

    if filter.item_type then
        sql = sql .. ' AND item_type = ?'
        params[#params + 1] = filter.item_type
    end

    sql = sql .. ' ORDER BY label ASC, id ASC'
    return call('Query', sql, params, { category = 'items.definition.list' })
end

function NexaItemsDatabase.UpdateDefinition(id, updates)
    local allowed = {
        'label',
        'description',
        'item_type',
        'weight',
        'stackable',
        'max_stack',
        'usable',
        'quickslot_allowed',
        'droppable',
        'tradeable',
        'destroyable',
        'container_allowed',
        'metadata_schema',
        'default_metadata',
        'durability_config',
        'expiration_config',
        'image_reference',
        'status',
        'version',
        'updated_by',
        'published_at',
        'deleted_at'
    }
    local assignments = {}
    local params = {}

    for _, field in ipairs(allowed) do
        if updates[field] ~= nil then
            assignments[#assignments + 1] = field .. ' = ?'
            params[#params + 1] = updates[field]
        end
    end

    if #assignments == 0 then
        return 0, nil
    end

    params[#params + 1] = id
    return call('Update', ('UPDATE nexa_item_definitions SET %s WHERE id = ?'):format(table.concat(assignments, ', ')), params, {
        category = 'items.definition.update'
    })
end

function NexaItemsDatabase.InsertVersion(payload)
    return call('Insert', [[
        INSERT INTO nexa_item_definition_versions (item_definition_id, version, snapshot, change_reason, created_by)
        VALUES (?, ?, ?, ?, ?)
    ]], {
        payload.item_definition_id,
        payload.version,
        payload.snapshot,
        payload.change_reason,
        payload.created_by
    }, { category = 'items.version.insert' })
end

function NexaItemsDatabase.InsertAction(payload)
    return call('Insert', [[
        INSERT INTO nexa_item_actions (
            item_definition_id, action_name, handler_name, side, priority, cooldown_ms,
            requires_active_player, requires_quickslot, configuration, enabled
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.item_definition_id,
        payload.action_name,
        payload.handler_name,
        payload.side,
        payload.priority or 0,
        payload.cooldown_ms or 0,
        payload.requires_active_player and 1 or 0,
        payload.requires_quickslot and 1 or 0,
        payload.configuration,
        payload.enabled == false and 0 or 1
    }, { category = 'items.action.insert' })
end

function NexaItemsDatabase.ListActions(definitionId)
    return call('Query', 'SELECT * FROM nexa_item_actions WHERE item_definition_id = ? AND enabled = 1 ORDER BY priority DESC, id ASC', {
        definitionId
    }, { category = 'items.action.list' })
end

function NexaItemsDatabase.InsertAsset(payload)
    return call('Insert', [[
        INSERT INTO nexa_item_assets (item_definition_id, asset_type, source_url, local_path, checksum, mime_type, size_bytes, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.item_definition_id,
        payload.asset_type,
        payload.source_url,
        payload.local_path,
        payload.checksum,
        payload.mime_type,
        payload.size_bytes,
        payload.status or 'pending'
    }, { category = 'items.asset.insert' })
end

function NexaItemsDatabase.InsertAudit(entry)
    return call('Insert', [[
        INSERT INTO nexa_item_audit (
            action, actor_account_id, item_name, old_version, new_version, before_state, after_state,
            reason, result, error_code, correlation_id, source_resource
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        entry.action,
        entry.actor_account_id,
        entry.item_name,
        entry.old_version,
        entry.new_version,
        entry.before_state,
        entry.after_state,
        entry.reason,
        entry.result,
        entry.error_code,
        entry.correlation_id,
        entry.source_resource
    }, { category = 'items.audit' })
end

function NexaItemsDatabase.GetSchema()
    return NEXA_ITEMS_TABLES
end
