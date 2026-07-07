local inventoryLimits = {
    maxItemNameLength = 64,
    maxCount = 1000
}

local function respond(success, code, message, data, meta, auditId)
    return NexaApiResponse(success, code, message, data, meta, auditId)
end

local function normalizeItemName(value)
    if type(value) ~= 'string' then
        return nil
    end

    local itemName = value:gsub('^%s+', ''):gsub('%s+$', '')

    if itemName == '' or #itemName > inventoryLimits.maxItemNameLength then
        return nil
    end

    if itemName:match('^[%w_]+$') == nil then
        return nil
    end

    return itemName
end

local function normalizeCount(value)
    local count = tonumber(value)

    if count == nil or count < 1 or count > inventoryLimits.maxCount or math.floor(count) ~= count then
        return nil
    end

    return count
end

local function getActor(source)
    local active = getActiveCharacter(source)

    if active == nil or not active.success or active.data == nil or active.data.character == nil then
        return nil, 'CHARACTER_NOT_LOADED'
    end

    return active.data.character, 'OK'
end

local function writeInventoryAudit(action, actor, itemName, count, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'inventory',
        severity = 'info',
        actorPlayerId = actor and actor.player_id or nil,
        actorCharacterId = actor and actor.id or nil,
        targetType = 'item',
        targetId = nil,
        action = action,
        resourceName = NEXA_API.resourceName,
        metadata = {
            itemName = itemName,
            count = count,
            context = metadata or {}
        }
    })

    return result and result.audit_id or nil
end

local function getItemCount(source, itemName)
    if GetResourceState('ox_inventory') ~= 'started' then
        return nil
    end

    local count = exports.ox_inventory:Search(source, 'count', itemName)

    return tonumber(count) or 0
end

function inventoryHasItem(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Itemdaten.', nil, nil, nil)
    end

    local itemName = normalizeItemName(payload.itemName)
    local count = normalizeCount(payload.count or 1)

    if itemName == nil or count == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Itemdaten.', nil, nil, nil)
    end

    local currentCount = getItemCount(source, itemName)

    if currentCount == nil then
        return respond(false, 'RESOURCE_UNAVAILABLE', 'Inventar ist nicht verfuegbar.', nil, nil, nil)
    end

    if currentCount < count then
        return respond(false, 'INSUFFICIENT_ITEMS', 'Nicht genug Gegenstaende vorhanden.', {
            itemName = itemName,
            count = currentCount
        }, nil, nil)
    end

    return respond(true, 'OK', 'Itembestand wurde geprueft.', {
        itemName = itemName,
        count = currentCount
    }, nil, nil)
end

function inventoryAddItem(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Itemdaten.', nil, nil, nil)
    end

    local itemName = normalizeItemName(payload.itemName)
    local count = normalizeCount(payload.count or 1)

    if itemName == nil or count == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Itemdaten.', nil, nil, nil)
    end

    if GetResourceState('ox_inventory') ~= 'started' then
        return respond(false, 'RESOURCE_UNAVAILABLE', 'Inventar ist nicht verfuegbar.', nil, nil, nil)
    end

    local ok = exports.ox_inventory:AddItem(source, itemName, count, payload.metadata or {})

    if not ok then
        return respond(false, 'CONFLICT', 'Item konnte nicht hinzugefuegt werden.', nil, nil, nil)
    end

    local auditId = writeInventoryAudit('inventory.addItem', actor, itemName, count, payload.audit or {})

    return respond(true, 'OK', 'Item wurde hinzugefuegt.', {
        itemName = itemName,
        count = count
    }, nil, auditId)
end

function inventoryRemoveItem(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Itemdaten.', nil, nil, nil)
    end

    local itemName = normalizeItemName(payload.itemName)
    local count = normalizeCount(payload.count or 1)

    if itemName == nil or count == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Itemdaten.', nil, nil, nil)
    end

    local currentCount = getItemCount(source, itemName)

    if currentCount == nil then
        return respond(false, 'RESOURCE_UNAVAILABLE', 'Inventar ist nicht verfuegbar.', nil, nil, nil)
    end

    if currentCount < count then
        return respond(false, 'INSUFFICIENT_ITEMS', 'Nicht genug Gegenstaende vorhanden.', nil, nil, nil)
    end

    local ok = exports.ox_inventory:RemoveItem(source, itemName, count, payload.metadata)

    if not ok then
        return respond(false, 'CONFLICT', 'Item konnte nicht entfernt werden.', nil, nil, nil)
    end

    local auditId = writeInventoryAudit('inventory.removeItem', actor, itemName, count, payload.audit or {})

    return respond(true, 'OK', 'Item wurde entfernt.', {
        itemName = itemName,
        count = count
    }, nil, auditId)
end

exports('inventory.hasItem', inventoryHasItem)
exports('inventory.addItem', inventoryAddItem)
exports('inventory.removeItem', inventoryRemoveItem)
