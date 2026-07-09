NexaShopsDatabase = {}

local createShopsTable = [[
CREATE TABLE IF NOT EXISTS shops (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    label VARCHAR(128) NOT NULL,
    shop_type VARCHAR(32) NOT NULL,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    owner_organization_id INT NULL,
    location_json LONGTEXT NULL,
    blip_json LONGTEXT NULL,
    npc_json LONGTEXT NULL,
    metadata_json LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_shops_name (name),
    KEY idx_shops_type (shop_type),
    KEY idx_shops_enabled (enabled),
    KEY idx_shops_owner_organization (owner_organization_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

local createShopItemsTable = [[
CREATE TABLE IF NOT EXISTS shop_items (
    id INT NOT NULL AUTO_INCREMENT,
    shop_id INT NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    price INT NOT NULL DEFAULT 0,
    currency_item VARCHAR(64) NULL,
    stock INT NULL,
    max_stock INT NULL,
    buyable TINYINT(1) NOT NULL DEFAULT 1,
    sellable TINYINT(1) NOT NULL DEFAULT 0,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    metadata_json LONGTEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_shop_items_shop (shop_id),
    KEY idx_shop_items_item (item_name),
    KEY idx_shop_items_enabled (enabled),
    CONSTRAINT fk_shop_items_shop
        FOREIGN KEY (shop_id) REFERENCES shops (id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

local migrations = {
    createShopsTable,
    createShopItemsTable
}

function NexaShopsDatabase.Migrate()
    for _, query in ipairs(migrations) do
        local ok, result = pcall(MySQL.query.await, query)

        if not ok then
            return false, result
        end
    end

    return true, nil
end

function NexaShopsDatabase.GetSchema()
    return {
        shops = {
            'id',
            'name',
            'label',
            'shop_type',
            'enabled',
            'owner_organization_id',
            'location_json',
            'blip_json',
            'npc_json',
            'metadata_json',
            'created_at',
            'updated_at'
        },
        shop_items = {
            'id',
            'shop_id',
            'item_name',
            'price',
            'currency_item',
            'stock',
            'max_stock',
            'buyable',
            'sellable',
            'enabled',
            'metadata_json',
            'created_at',
            'updated_at'
        }
    }
end

function NexaShopsDatabase.InsertShop(payload)
    return MySQL.insert.await([[
        INSERT INTO shops (name, label, shop_type, enabled, owner_organization_id, location_json, blip_json, npc_json, metadata_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.name,
        payload.label,
        payload.shop_type,
        payload.enabled and 1 or 0,
        payload.owner_organization_id,
        payload.location_json,
        payload.blip_json,
        payload.npc_json,
        payload.metadata_json
    })
end

function NexaShopsDatabase.GetShopById(id)
    return MySQL.single.await([[
        SELECT id, name, label, shop_type, enabled, owner_organization_id, location_json, blip_json, npc_json, metadata_json, created_at, updated_at
        FROM shops
        WHERE id = ?
        LIMIT 1
    ]], {
        id
    })
end

function NexaShopsDatabase.GetShopByName(name)
    return MySQL.single.await([[
        SELECT id, name, label, shop_type, enabled, owner_organization_id, location_json, blip_json, npc_json, metadata_json, created_at, updated_at
        FROM shops
        WHERE name = ?
        LIMIT 1
    ]], {
        name
    })
end

function NexaShopsDatabase.ListShops(filter)
    filter = filter or {}

    local query = [[
        SELECT id, name, label, shop_type, enabled, owner_organization_id, location_json, blip_json, npc_json, metadata_json, created_at, updated_at
        FROM shops
        WHERE 1 = 1
    ]]
    local params = {}

    if filter.shop_type then
        query = query .. ' AND shop_type = ?'
        params[#params + 1] = filter.shop_type
    end

    if filter.enabled ~= nil then
        query = query .. ' AND enabled = ?'
        params[#params + 1] = filter.enabled and 1 or 0
    end

    if filter.owner_organization_id then
        query = query .. ' AND owner_organization_id = ?'
        params[#params + 1] = filter.owner_organization_id
    end

    query = query .. ' ORDER BY label ASC, id ASC'

    return MySQL.query.await(query, params)
end

function NexaShopsDatabase.UpdateShop(id, updates)
    local assignments = {}
    local params = {}

    for _, field in ipairs({
        'name',
        'label',
        'shop_type',
        'enabled',
        'owner_organization_id',
        'location_json',
        'blip_json',
        'npc_json',
        'metadata_json'
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

    return MySQL.update.await(('UPDATE shops SET %s WHERE id = ?'):format(table.concat(assignments, ', ')), params)
end

function NexaShopsDatabase.SetShopEnabled(id, enabled)
    return MySQL.update.await('UPDATE shops SET enabled = ? WHERE id = ?', {
        enabled and 1 or 0,
        id
    })
end

function NexaShopsDatabase.DeleteShop(id)
    return MySQL.update.await('DELETE FROM shops WHERE id = ?', {
        id
    })
end

function NexaShopsDatabase.InsertShopItem(payload)
    return MySQL.insert.await([[
        INSERT INTO shop_items (shop_id, item_name, price, currency_item, stock, max_stock, buyable, sellable, enabled, metadata_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        payload.shop_id,
        payload.item_name,
        payload.price,
        payload.currency_item,
        payload.stock,
        payload.max_stock,
        payload.buyable and 1 or 0,
        payload.sellable and 1 or 0,
        payload.enabled and 1 or 0,
        payload.metadata_json
    })
end

function NexaShopsDatabase.GetShopItem(id)
    return MySQL.single.await([[
        SELECT id, shop_id, item_name, price, currency_item, stock, max_stock, buyable, sellable, enabled, metadata_json, created_at, updated_at
        FROM shop_items
        WHERE id = ?
        LIMIT 1
    ]], {
        id
    })
end

function NexaShopsDatabase.ListShopItems(shopId)
    return MySQL.query.await([[
        SELECT id, shop_id, item_name, price, currency_item, stock, max_stock, buyable, sellable, enabled, metadata_json, created_at, updated_at
        FROM shop_items
        WHERE shop_id = ?
        ORDER BY item_name ASC, id ASC
    ]], {
        shopId
    })
end

function NexaShopsDatabase.UpdateShopItem(id, updates)
    local assignments = {}
    local params = {}

    for _, field in ipairs({
        'item_name',
        'price',
        'currency_item',
        'stock',
        'max_stock',
        'buyable',
        'sellable',
        'enabled',
        'metadata_json'
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

    return MySQL.update.await(('UPDATE shop_items SET %s WHERE id = ?'):format(table.concat(assignments, ', ')), params)
end

function NexaShopsDatabase.RemoveShopItem(id)
    return MySQL.update.await('DELETE FROM shop_items WHERE id = ?', {
        id
    })
end
