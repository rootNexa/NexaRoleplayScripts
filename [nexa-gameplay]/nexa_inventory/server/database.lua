NexaInventoryDatabase = {}

local createInventoriesTable = [[
CREATE TABLE IF NOT EXISTS inventories (
    id INT NOT NULL AUTO_INCREMENT,
    owner_type VARCHAR(32) NOT NULL,
    owner_id VARCHAR(64) NOT NULL,
    label VARCHAR(128) NULL,
    max_weight INT NOT NULL DEFAULT 0,
    max_slots INT NOT NULL DEFAULT 0,
    metadata_json LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_inventories_owner (owner_type, owner_id),
    KEY idx_inventories_owner_type (owner_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

local createInventoryItemsTable = [[
CREATE TABLE IF NOT EXISTS inventory_items (
    id INT NOT NULL AUTO_INCREMENT,
    inventory_id INT NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    slot INT NULL,
    amount INT NOT NULL DEFAULT 1,
    metadata_json LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_inventory_items_inventory (inventory_id),
    KEY idx_inventory_items_item_name (item_name),
    KEY idx_inventory_items_slot (inventory_id, slot),
    CONSTRAINT fk_inventory_items_inventory
        FOREIGN KEY (inventory_id)
        REFERENCES inventories (id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

local migrations = {
    createInventoriesTable,
    createInventoryItemsTable
}

function NexaInventoryDatabase.Migrate()
    for _, query in ipairs(migrations) do
        local ok, result = pcall(MySQL.query.await, query)

        if not ok then
            return false, result
        end
    end

    return true, nil
end

function NexaInventoryDatabase.GetSchema()
    return {
        inventories = {
            'id',
            'owner_type',
            'owner_id',
            'label',
            'max_weight',
            'max_slots',
            'metadata_json',
            'created_at',
            'updated_at'
        },
        inventory_items = {
            'id',
            'inventory_id',
            'item_name',
            'slot',
            'amount',
            'metadata_json',
            'created_at',
            'updated_at'
        }
    }
end

function NexaInventoryDatabase.InsertInventory(payload)
    return MySQL.insert.await([[
        INSERT INTO inventories (
            owner_type,
            owner_id,
            label,
            max_weight,
            max_slots,
            metadata_json
        )
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        payload.owner_type,
        payload.owner_id,
        payload.label,
        payload.max_weight,
        payload.max_slots,
        payload.metadata_json
    })
end

function NexaInventoryDatabase.GetInventoryById(id)
    return MySQL.single.await([[
        SELECT id, owner_type, owner_id, label, max_weight, max_slots, metadata_json, created_at, updated_at
        FROM inventories
        WHERE id = ?
        LIMIT 1
    ]], {
        id
    })
end

function NexaInventoryDatabase.GetInventoryByOwner(ownerType, ownerId)
    return MySQL.single.await([[
        SELECT id, owner_type, owner_id, label, max_weight, max_slots, metadata_json, created_at, updated_at
        FROM inventories
        WHERE owner_type = ? AND owner_id = ?
        LIMIT 1
    ]], {
        ownerType,
        ownerId
    })
end

function NexaInventoryDatabase.ListInventoryItems(inventoryId)
    return MySQL.query.await([[
        SELECT id, inventory_id, item_name, slot, amount, metadata_json, created_at, updated_at
        FROM inventory_items
        WHERE inventory_id = ?
        ORDER BY COALESCE(slot, 999999), id
    ]], {
        inventoryId
    })
end

function NexaInventoryDatabase.GetInventoryItem(id)
    return MySQL.single.await([[
        SELECT id, inventory_id, item_name, slot, amount, metadata_json, created_at, updated_at
        FROM inventory_items
        WHERE id = ?
        LIMIT 1
    ]], {
        id
    })
end

function NexaInventoryDatabase.InsertInventoryItem(payload)
    return MySQL.insert.await([[
        INSERT INTO inventory_items (
            inventory_id,
            item_name,
            slot,
            amount,
            metadata_json
        )
        VALUES (?, ?, ?, ?, ?)
    ]], {
        payload.inventory_id,
        payload.item_name,
        payload.slot,
        payload.amount,
        payload.metadata_json
    })
end

function NexaInventoryDatabase.UpdateInventoryItemAmount(id, amount)
    return MySQL.update.await([[
        UPDATE inventory_items
        SET amount = ?
        WHERE id = ?
    ]], {
        amount,
        id
    })
end

function NexaInventoryDatabase.UpdateInventoryItemSlot(id, inventoryId, slot)
    return MySQL.update.await([[
        UPDATE inventory_items
        SET inventory_id = ?, slot = ?
        WHERE id = ?
    ]], {
        inventoryId,
        slot,
        id
    })
end

function NexaInventoryDatabase.DeleteInventoryItem(id)
    return MySQL.update.await('DELETE FROM inventory_items WHERE id = ?', {
        id
    })
end

function NexaInventoryDatabase.ClearInventory(inventoryId)
    return MySQL.update.await('DELETE FROM inventory_items WHERE inventory_id = ?', {
        inventoryId
    })
end
