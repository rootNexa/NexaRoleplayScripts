NexaInventoryDatabase = {}

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
            code = NEXA_INVENTORY_ERRORS.databaseError,
            message = 'Core database is not ready.'
        }
    end

    return db[method](sql, params or {}, options or {
        category = 'inventory'
    })
end

function NexaInventoryDatabase.Migrate()
    local db = database()

    if not db or not db.RegisterMigration then
        return false, 'Core database is not ready.'
    end

    db.RegisterMigration({
        id = '060_inventory_foundation',
        description = 'Create server-authoritative inventory foundation tables',
        transaction = false,
        statements = {
            [[CREATE TABLE IF NOT EXISTS nexa_inventories (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                inventory_type VARCHAR(32) NOT NULL,
                owner_type VARCHAR(32) NOT NULL,
                owner_id VARCHAR(64) NOT NULL,
                slot_limit INT NOT NULL DEFAULT 0,
                weight_limit INT NOT NULL DEFAULT 0,
                current_weight INT NOT NULL DEFAULT 0,
                status VARCHAR(32) NOT NULL DEFAULT 'ready',
                version BIGINT UNSIGNED NOT NULL DEFAULT 1,
                metadata LONGTEXT NULL,
                expires_at TIMESTAMP NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_nexa_inventories_owner (inventory_type, owner_type, owner_id),
                KEY idx_nexa_inventories_owner (owner_type, owner_id),
                KEY idx_nexa_inventories_type_status (inventory_type, status),
                KEY idx_nexa_inventories_expires (expires_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
            [[CREATE TABLE IF NOT EXISTS nexa_inventory_items (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                inventory_id BIGINT UNSIGNED NOT NULL,
                item_name VARCHAR(64) NOT NULL,
                slot INT NULL,
                amount INT NOT NULL DEFAULT 1,
                metadata LONGTEXT NULL,
                unit_weight INT NOT NULL DEFAULT 0,
                total_weight INT NOT NULL DEFAULT 0,
                durability INT NULL,
                expires_at TIMESTAMP NULL,
                instance_id VARCHAR(64) NULL,
                version BIGINT UNSIGNED NOT NULL DEFAULT 1,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_nexa_inventory_items_slot (inventory_id, slot),
                UNIQUE KEY uq_nexa_inventory_items_instance (instance_id),
                KEY idx_nexa_inventory_items_inventory (inventory_id),
                KEY idx_nexa_inventory_items_item (item_name),
                KEY idx_nexa_inventory_items_expires (expires_at),
                CONSTRAINT fk_nexa_inventory_items_inventory
                    FOREIGN KEY (inventory_id)
                    REFERENCES nexa_inventories (id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
            [[CREATE TABLE IF NOT EXISTS nexa_inventory_quickslots (
                character_id BIGINT UNSIGNED NOT NULL,
                quickslot INT NOT NULL,
                inventory_item_id BIGINT UNSIGNED NOT NULL,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (character_id, quickslot),
                KEY idx_nexa_inventory_quickslots_item (inventory_item_id),
                CONSTRAINT fk_nexa_inventory_quickslots_item
                    FOREIGN KEY (inventory_item_id)
                    REFERENCES nexa_inventory_items (id)
                    ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
            [[CREATE TABLE IF NOT EXISTS nexa_inventory_audit (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                action VARCHAR(64) NOT NULL,
                actor_type VARCHAR(32) NULL,
                actor_account_id BIGINT UNSIGNED NULL,
                actor_character_id BIGINT UNSIGNED NULL,
                source_inventory_id BIGINT UNSIGNED NULL,
                target_inventory_id BIGINT UNSIGNED NULL,
                inventory_item_id BIGINT UNSIGNED NULL,
                item_name VARCHAR(64) NULL,
                amount INT NULL,
                before_state LONGTEXT NULL,
                after_state LONGTEXT NULL,
                reason VARCHAR(128) NULL,
                result VARCHAR(32) NOT NULL,
                error_code VARCHAR(64) NULL,
                correlation_id VARCHAR(96) NULL,
                source_resource VARCHAR(64) NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                metadata LONGTEXT NULL,
                PRIMARY KEY (id),
                KEY idx_nexa_inventory_audit_action (action),
                KEY idx_nexa_inventory_audit_actor (actor_character_id),
                KEY idx_nexa_inventory_audit_inventory (source_inventory_id, target_inventory_id),
                KEY idx_nexa_inventory_audit_correlation (correlation_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]]
        }
    })

    return db.RunMigrations()
end

function NexaInventoryDatabase.InsertInventory(payload)
    return call('Insert', [[
        INSERT INTO nexa_inventories (
            inventory_type, owner_type, owner_id, slot_limit, weight_limit, current_weight, status, metadata, expires_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.inventory_type,
        payload.owner_type,
        payload.owner_id,
        payload.slot_limit,
        payload.weight_limit,
        payload.current_weight or 0,
        payload.status or NEXA_INVENTORY_STATUS.ready,
        payload.metadata,
        payload.expires_at
    }, { category = 'inventory.create' })
end

function NexaInventoryDatabase.GetInventoryById(id)
    return call('Single', 'SELECT * FROM nexa_inventories WHERE id = ? LIMIT 1', { id }, { category = 'inventory.get' })
end

function NexaInventoryDatabase.GetInventoryByOwner(inventoryType, ownerType, ownerId)
    return call('Single', [[
        SELECT *
        FROM nexa_inventories
        WHERE inventory_type = ? AND owner_type = ? AND owner_id = ?
        LIMIT 1
    ]], { inventoryType, ownerType, ownerId }, { category = 'inventory.get_owner' })
end

function NexaInventoryDatabase.ListInventoryItems(inventoryId)
    return call('Query', [[
        SELECT *
        FROM nexa_inventory_items
        WHERE inventory_id = ?
        ORDER BY COALESCE(slot, 999999), id
    ]], { inventoryId }, { category = 'inventory.items.list' })
end

function NexaInventoryDatabase.GetInventoryItem(id)
    return call('Single', 'SELECT * FROM nexa_inventory_items WHERE id = ? LIMIT 1', { id }, { category = 'inventory.item.get' })
end

function NexaInventoryDatabase.GetInventoryItemBySlot(inventoryId, slot)
    return call('Single', 'SELECT * FROM nexa_inventory_items WHERE inventory_id = ? AND slot = ? LIMIT 1', { inventoryId, slot }, { category = 'inventory.item.slot' })
end

function NexaInventoryDatabase.InsertInventoryItem(payload)
    return call('Insert', [[
        INSERT INTO nexa_inventory_items (
            inventory_id, item_name, slot, amount, metadata, unit_weight, total_weight, durability, expires_at, instance_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.inventory_id,
        payload.item_name,
        payload.slot,
        payload.amount,
        payload.metadata,
        payload.unit_weight,
        payload.total_weight,
        payload.durability,
        payload.expires_at,
        payload.instance_id
    }, { category = 'inventory.item.insert' })
end

function NexaInventoryDatabase.UpdateInventoryItem(id, updates)
    local fields = {}
    local params = {}

    for _, field in ipairs({ 'inventory_id', 'slot', 'amount', 'metadata', 'unit_weight', 'total_weight', 'durability', 'expires_at', 'instance_id' }) do
        if updates[field] ~= nil then
            fields[#fields + 1] = field .. ' = ?'
            params[#params + 1] = updates[field]
        end
    end

    fields[#fields + 1] = 'version = version + 1'
    params[#params + 1] = id

    return call('Update', ('UPDATE nexa_inventory_items SET %s WHERE id = ?'):format(table.concat(fields, ', ')), params, {
        category = 'inventory.item.update'
    })
end

function NexaInventoryDatabase.DeleteInventoryItem(id)
    return call('Delete', 'DELETE FROM nexa_inventory_items WHERE id = ?', { id }, { category = 'inventory.item.delete' })
end

function NexaInventoryDatabase.UpdateInventoryWeight(inventoryId, weight)
    return call('Update', 'UPDATE nexa_inventories SET current_weight = ?, version = version + 1 WHERE id = ?', {
        weight,
        inventoryId
    }, { category = 'inventory.weight.update' })
end

function NexaInventoryDatabase.UpdateInventoryLimits(inventoryId, limits)
    return call('Update', 'UPDATE nexa_inventories SET slot_limit = ?, weight_limit = ?, version = version + 1 WHERE id = ?', {
        limits.slot_limit,
        limits.weight_limit,
        inventoryId
    }, { category = 'inventory.limits.update' })
end

function NexaInventoryDatabase.SetInventoryStatus(inventoryId, status)
    return call('Update', 'UPDATE nexa_inventories SET status = ?, version = version + 1 WHERE id = ?', {
        status,
        inventoryId
    }, { category = 'inventory.status.update' })
end

function NexaInventoryDatabase.AssignQuickslot(characterId, quickslot, inventoryItemId)
    return call('Update', [[
        INSERT INTO nexa_inventory_quickslots (character_id, quickslot, inventory_item_id)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE inventory_item_id = VALUES(inventory_item_id), updated_at = CURRENT_TIMESTAMP
    ]], { characterId, quickslot, inventoryItemId }, { category = 'inventory.quickslot.assign' })
end

function NexaInventoryDatabase.ClearQuickslot(characterId, quickslot)
    return call('Delete', 'DELETE FROM nexa_inventory_quickslots WHERE character_id = ? AND quickslot = ?', {
        characterId,
        quickslot
    }, { category = 'inventory.quickslot.clear' })
end

function NexaInventoryDatabase.ListQuickslots(characterId)
    return call('Query', 'SELECT * FROM nexa_inventory_quickslots WHERE character_id = ? ORDER BY quickslot', {
        characterId
    }, { category = 'inventory.quickslot.list' })
end

function NexaInventoryDatabase.CleanupQuickslotsForItem(inventoryItemId)
    return call('Delete', 'DELETE FROM nexa_inventory_quickslots WHERE inventory_item_id = ?', {
        inventoryItemId
    }, { category = 'inventory.quickslot.cleanup' })
end

function NexaInventoryDatabase.InsertAudit(entry)
    return call('Insert', [[
        INSERT INTO nexa_inventory_audit (
            action, actor_type, actor_account_id, actor_character_id, source_inventory_id, target_inventory_id,
            inventory_item_id, item_name, amount, before_state, after_state, reason, result, error_code,
            correlation_id, source_resource, metadata
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        entry.action,
        entry.actor_type,
        entry.actor_account_id,
        entry.actor_character_id,
        entry.source_inventory_id,
        entry.target_inventory_id,
        entry.inventory_item_id,
        entry.item_name,
        entry.amount,
        entry.before_state,
        entry.after_state,
        entry.reason,
        entry.result,
        entry.error_code,
        entry.correlation_id,
        entry.source_resource,
        entry.metadata
    }, { category = 'inventory.audit' })
end

function NexaInventoryDatabase.Transaction(queries, options)
    local db = database()

    if not db or not db.Transaction then
        return nil, {
            code = NEXA_INVENTORY_ERRORS.databaseError,
            message = 'Core database transaction is not ready.'
        }
    end

    return db.Transaction(queries, options or { category = 'inventory.transaction' })
end

function NexaInventoryDatabase.GetSchema()
    return NEXA_INVENTORY_TABLES
end
