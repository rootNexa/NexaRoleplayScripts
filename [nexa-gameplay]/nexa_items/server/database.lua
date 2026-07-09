NexaItemsDatabase = {}

local createItemsTable = [[
CREATE TABLE IF NOT EXISTS items (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(128) NOT NULL,
    description TEXT NULL,
    item_type VARCHAR(32) NOT NULL,
    image_url TEXT NULL,
    weight INT NOT NULL DEFAULT 0,
    stackable TINYINT(1) NOT NULL DEFAULT 1,
    max_stack INT NOT NULL DEFAULT 1,
    usable TINYINT(1) NOT NULL DEFAULT 0,
    tradable TINYINT(1) NOT NULL DEFAULT 1,
    droppable TINYINT(1) NOT NULL DEFAULT 1,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    metadata_json LONGTEXT NULL,
    use_config_json LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_items_name (name),
    KEY idx_items_type (item_type),
    KEY idx_items_enabled (enabled),
    KEY idx_items_usable (usable)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

local migrations = {
    createItemsTable
}

function NexaItemsDatabase.Migrate()
    for _, query in ipairs(migrations) do
        local ok, result = pcall(MySQL.query.await, query)

        if not ok then
            return false, result
        end
    end

    return true, nil
end

function NexaItemsDatabase.GetSchema()
    return {
        items = {
            'id',
            'name',
            'label',
            'description',
            'item_type',
            'image_url',
            'weight',
            'stackable',
            'max_stack',
            'usable',
            'tradable',
            'droppable',
            'enabled',
            'metadata_json',
            'use_config_json',
            'created_at',
            'updated_at'
        }
    }
end

function NexaItemsDatabase.InsertItem(payload)
    return MySQL.insert.await([[
        INSERT INTO items (
            name,
            label,
            description,
            item_type,
            image_url,
            weight,
            stackable,
            max_stack,
            usable,
            tradable,
            droppable,
            enabled,
            metadata_json,
            use_config_json
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.name,
        payload.label,
        payload.description,
        payload.item_type,
        payload.image_url,
        payload.weight,
        payload.stackable and 1 or 0,
        payload.max_stack,
        payload.usable and 1 or 0,
        payload.tradable and 1 or 0,
        payload.droppable and 1 or 0,
        payload.enabled and 1 or 0,
        payload.metadata_json,
        payload.use_config_json
    })
end

function NexaItemsDatabase.GetItemById(id)
    return MySQL.single.await([[
        SELECT id, name, label, description, item_type, image_url, weight, stackable, max_stack, usable, tradable, droppable, enabled, metadata_json, use_config_json, created_at, updated_at
        FROM items
        WHERE id = ?
        LIMIT 1
    ]], {
        id
    })
end

function NexaItemsDatabase.GetItemByName(name)
    return MySQL.single.await([[
        SELECT id, name, label, description, item_type, image_url, weight, stackable, max_stack, usable, tradable, droppable, enabled, metadata_json, use_config_json, created_at, updated_at
        FROM items
        WHERE name = ?
        LIMIT 1
    ]], {
        name
    })
end

function NexaItemsDatabase.ListItems(filter)
    filter = filter or {}

    local query = [[
        SELECT id, name, label, description, item_type, image_url, weight, stackable, max_stack, usable, tradable, droppable, enabled, metadata_json, use_config_json, created_at, updated_at
        FROM items
        WHERE 1 = 1
    ]]
    local params = {}

    if filter.item_type then
        query = query .. ' AND item_type = ?'
        params[#params + 1] = filter.item_type
    end

    if filter.enabled ~= nil then
        query = query .. ' AND enabled = ?'
        params[#params + 1] = filter.enabled and 1 or 0
    end

    if filter.usable ~= nil then
        query = query .. ' AND usable = ?'
        params[#params + 1] = filter.usable and 1 or 0
    end

    if filter.stackable ~= nil then
        query = query .. ' AND stackable = ?'
        params[#params + 1] = filter.stackable and 1 or 0
    end

    query = query .. ' ORDER BY label ASC, id ASC'

    return MySQL.query.await(query, params)
end

function NexaItemsDatabase.UpdateItem(id, updates)
    local assignments = {}
    local params = {}

    for _, field in ipairs({
        'name',
        'label',
        'description',
        'item_type',
        'image_url',
        'weight',
        'stackable',
        'max_stack',
        'usable',
        'tradable',
        'droppable',
        'enabled',
        'metadata_json',
        'use_config_json'
    }) do
        if updates[field] ~= nil then
            assignments[#assignments + 1] = field .. ' = ?'
            params[#params + 1] = updates[field]
        end
    end

    if #assignments == 0 then
        return 0
    end

    params[#params + 1] = id

    return MySQL.update.await(('UPDATE items SET %s WHERE id = ?'):format(table.concat(assignments, ', ')), params)
end

function NexaItemsDatabase.SetItemEnabled(id, enabled)
    return MySQL.update.await([[
        UPDATE items
        SET enabled = ?
        WHERE id = ?
    ]], {
        enabled and 1 or 0,
        id
    })
end

function NexaItemsDatabase.DeleteItem(id)
    return MySQL.update.await('DELETE FROM items WHERE id = ?', {
        id
    })
end
