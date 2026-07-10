local migrated = false

Inventory = {
    locks = {},
    loadedByCharacter = {},
    drops = {}
}

local function response(success, code, message, data, meta)
    return {
        ok = success == true,
        success = success == true,
        code = code or (success and 'OK' or NEXA_INVENTORY_ERRORS.invalidInput),
        message = message or '',
        data = data,
        meta = meta,
        error = success == true and nil or {
            code = code,
            message = message
        }
    }
end

local function ok(data, message, meta)
    return response(true, 'OK', message or 'OK', data, meta)
end

local function fail(code, message, meta)
    return response(false, code, message or code, nil, meta)
end

local function encode(value)
    local encodedOk, encoded = pcall(json.encode, value or {})
    return encodedOk and encoded or '{}'
end

local function decode(value, fallback)
    if type(value) ~= 'string' or value == '' then
        return fallback
    end

    local decodedOk, decoded = pcall(json.decode, value)
    return decodedOk and decoded or fallback
end

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then
        return nil
    end

    local coreOk, core = pcall(function()
        return exports['nexa-core']:GetCoreObject()
    end)

    return coreOk and core or nil
end

local function log(level, category, message, context)
    local core = getCore()

    if core and core.Logger and core.Logger[level] then
        core.Logger[level](category, message, context)
        return
    end

    print(('[%s] [%s] %s %s'):format(NEXA_INVENTORY.resourceName, level, message, encode(context)))
end

local function emit(eventName, payload)
    local core = getCore()

    if core and core.EventBus then
        core.EventBus.Emit(eventName, payload, {
            resource = NEXA_INVENTORY.resourceName
        })
    end
end

local function normalizeId(value)
    local id = tonumber(value)
    return id and id > 0 and id % 1 == 0 and math.floor(id) or nil
end

local function normalizeSource(value)
    local source = tonumber(value)
    return source and source > 0 and source % 1 == 0 and math.floor(source) or nil
end

local function normalizeString(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    local normalized = value:gsub('^%s+', ''):gsub('%s+$', '')

    if normalized == '' or (maxLength and #normalized > maxLength) then
        return nil
    end

    return normalized
end

local function normalizeSlug(value, maxLength)
    value = normalizeString(value, maxLength)

    if not value then
        return nil
    end

    value = value:lower()

    if value:find('^[a-z0-9_%-]+$') == nil then
        return nil
    end

    return value
end

local function normalizeAmount(value)
    value = tonumber(value)

    if not value or value < 1 or value % 1 ~= 0 then
        return nil
    end

    return math.floor(value)
end

local function normalizeSlot(value)
    value = tonumber(value)

    if not value or value < 1 or value % 1 ~= 0 then
        return nil
    end

    return math.floor(value)
end

local function metadataDepth(value, depth, seen)
    if type(value) ~= 'table' then
        return depth
    end

    if seen[value] then
        return 999
    end

    seen[value] = true
    local maxDepth = depth

    for key, child in pairs(value) do
        local keyType = type(key)
        local childType = type(child)

        if keyType == 'function' or keyType == 'thread' or keyType == 'userdata' or childType == 'function' or childType == 'thread' or childType == 'userdata' then
            return 999
        end

        maxDepth = math.max(maxDepth, metadataDepth(child, depth + 1, seen))
    end

    seen[value] = nil
    return maxDepth
end

local function validateMetadata(metadata)
    if metadata == nil then
        return {}, nil
    end

    if type(metadata) ~= 'table' then
        return nil, fail(NEXA_INVENTORY_ERRORS.itemMetadataInvalid, 'Metadata must be a table.')
    end

    if metadataDepth(metadata, 1, {}) > NexaInventoryConfig.maxMetadataDepth then
        return nil, fail(NEXA_INVENTORY_ERRORS.itemMetadataInvalid, 'Metadata is too deep.')
    end

    local encoded = encode(metadata)

    if #encoded > NexaInventoryConfig.maxMetadataBytes then
        return nil, fail(NEXA_INVENTORY_ERRORS.itemMetadataInvalid, 'Metadata is too large.')
    end

    return metadata, nil
end

local function normalizeInventory(row)
    if type(row) ~= 'table' then
        return row
    end

    row.id = normalizeId(row.id)
    row.slot_limit = tonumber(row.slot_limit) or 0
    row.weight_limit = tonumber(row.weight_limit) or 0
    row.current_weight = tonumber(row.current_weight) or 0
    row.version = tonumber(row.version) or 1
    row.metadata = decode(row.metadata, {})
    return row
end

local function normalizeItem(row)
    if type(row) ~= 'table' then
        return row
    end

    row.id = normalizeId(row.id)
    row.inventory_id = normalizeId(row.inventory_id)
    row.slot = row.slot and normalizeSlot(row.slot) or nil
    row.amount = tonumber(row.amount) or 0
    row.unit_weight = tonumber(row.unit_weight) or 0
    row.total_weight = tonumber(row.total_weight) or 0
    row.durability = row.durability and tonumber(row.durability) or nil
    row.version = tonumber(row.version) or 1
    row.metadata = decode(row.metadata, {})
    return row
end

local function correlationId()
    return ('inv:%s:%s:%s'):format(os.time(), GetGameTimer and GetGameTimer() or 0, math.random(100000, 999999))
end

local function normalizeContext(context, action)
    context = type(context) == 'table' and context or {}
    return {
        action = action,
        actor_type = context.actor_type or (context.source and 'player' or 'system'),
        actor_account_id = normalizeId(context.actor_account_id),
        actor_character_id = normalizeId(context.actor_character_id),
        source = normalizeSource(context.source),
        reason = normalizeString(context.reason or context.action or action, 128),
        correlation_id = normalizeString(context.correlation_id, 96) or correlationId(),
        source_resource = normalizeString(context.source_resource or GetInvokingResource() or NEXA_INVENTORY.resourceName, 64),
        metadata = context.metadata or {}
    }
end

local function audit(action, context, result, payload)
    context = normalizeContext(context, action)
    payload = payload or {}

    NexaInventoryDatabase.InsertAudit({
        action = action,
        actor_type = context.actor_type,
        actor_account_id = context.actor_account_id,
        actor_character_id = context.actor_character_id,
        source_inventory_id = payload.source_inventory_id,
        target_inventory_id = payload.target_inventory_id,
        inventory_item_id = payload.inventory_item_id,
        item_name = payload.item_name,
        amount = payload.amount,
        before_state = payload.before_state and encode(payload.before_state) or nil,
        after_state = payload.after_state and encode(payload.after_state) or nil,
        reason = context.reason,
        result = result.ok == true and 'success' or 'failed',
        error_code = result.ok == true and nil or result.code,
        correlation_id = context.correlation_id,
        source_resource = context.source_resource,
        metadata = encode(context.metadata)
    })
end

local function itemDefinition(itemName)
    itemName = normalizeSlug(itemName, NexaInventoryConfig.maxItemNameLength)

    if not itemName then
        return nil, fail(NEXA_INVENTORY_ERRORS.itemDefinitionNotFound, 'Item name is invalid.')
    end

    if GetResourceState('nexa_items') == 'started' then
        local itemOk, itemResponse = pcall(function()
            return exports.nexa_items:GetItem(itemName)
        end)

        if itemOk and type(itemResponse) == 'table' and itemResponse.success == true and type(itemResponse.data) == 'table' then
            local item = itemResponse.data
            return {
                name = item.name,
                label = item.label,
                weight = tonumber(item.weight) or 0,
                stackable = item.stackable == true,
                max_stack = tonumber(item.max_stack) or 1,
                usable = item.usable == true,
                metadata = item.metadata or {}
            }, nil
        end
    end

    local fallback = NexaInventoryConfig.internalCatalog[itemName]

    if fallback then
        return fallback, nil
    end

    return nil, fail(NEXA_INVENTORY_ERRORS.itemDefinitionNotFound, 'Item definition not found.', {
        item_name = itemName
    })
end

Weight = {}

function Weight.CalculateItem(definition, amount, metadata)
    amount = normalizeAmount(amount)

    if not definition or not amount then
        return nil
    end

    local unitWeight = tonumber(definition.weight) or 0

    if unitWeight < 0 then
        unitWeight = 0
    end

    return {
        unit = unitWeight,
        total = unitWeight * amount,
        metadata = metadata
    }
end

local function getInventoryById(inventoryId)
    inventoryId = normalizeId(inventoryId)

    if not inventoryId then
        return nil, fail(NEXA_INVENTORY_ERRORS.notFound, 'Inventory ID is invalid.')
    end

    local row, err = NexaInventoryDatabase.GetInventoryById(inventoryId)

    if err then
        return nil, fail(NEXA_INVENTORY_ERRORS.databaseError, 'Inventory could not be loaded.', err)
    end

    if not row then
        return nil, fail(NEXA_INVENTORY_ERRORS.notFound, 'Inventory not found.', {
            inventory_id = inventoryId
        })
    end

    return normalizeInventory(row), nil
end

local function listItems(inventoryId)
    local rows, err = NexaInventoryDatabase.ListInventoryItems(inventoryId)

    if err then
        return nil, fail(NEXA_INVENTORY_ERRORS.databaseError, 'Inventory items could not be loaded.', err)
    end

    for _, item in ipairs(rows or {}) do
        normalizeItem(item)
    end

    return rows or {}, nil
end

function Weight.CalculateInventory(inventoryId)
    local items, invalid = listItems(inventoryId)

    if invalid then
        return nil, invalid
    end

    local weight = 0

    for _, item in ipairs(items) do
        weight = weight + (tonumber(item.total_weight) or 0)
    end

    return weight, nil
end

function Weight.Recalculate(inventoryId)
    inventoryId = normalizeId(inventoryId)

    if not inventoryId then
        return fail(NEXA_INVENTORY_ERRORS.notFound, 'Inventory ID is invalid.')
    end

    local weight, invalid = Weight.CalculateInventory(inventoryId)

    if invalid then
        return invalid
    end

    local _, err = NexaInventoryDatabase.UpdateInventoryWeight(inventoryId, weight)

    if err then
        return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Weight could not be updated.', err)
    end

    emit(NEXA_INVENTORY_EVENTS.weightChanged, {
        inventoryId = inventoryId,
        weight = weight
    })

    return ok({
        inventory_id = inventoryId,
        weight = weight
    }, 'Weight recalculated.')
end

function Weight.CanAdd(inventory, definition, amount, metadata)
    local calculated = Weight.CalculateItem(definition, amount, metadata)

    if not calculated then
        return false, NEXA_INVENTORY_ERRORS.itemAmountInvalid
    end

    if inventory.weight_limit > 0 and inventory.current_weight + calculated.total > inventory.weight_limit then
        return false, NEXA_INVENTORY_ERRORS.weightExceeded
    end

    return true, nil, calculated
end

Slots = {}

function Slots.IsValid(inventory, slot)
    slot = normalizeSlot(slot)
    return slot ~= nil and (inventory.slot_limit == 0 or slot <= inventory.slot_limit)
end

function Slots.IsOccupied(inventoryId, slot)
    local row = NexaInventoryDatabase.GetInventoryItemBySlot(inventoryId, slot)
    return row ~= nil
end

function Slots.FindFree(inventory)
    if inventory.slot_limit == 0 then
        return nil
    end

    local items = listItems(inventory.id) or {}
    local occupied = {}

    for _, item in ipairs(items) do
        if item.slot then
            occupied[item.slot] = true
        end
    end

    for slot = 1, inventory.slot_limit do
        if not occupied[slot] then
            return slot
        end
    end

    return nil
end

local function metadataEquals(left, right)
    return encode(left or {}) == encode(right or {})
end

function Slots.FindStack(inventory, definition, metadata)
    if not definition.stackable then
        return nil
    end

    local items = listItems(inventory.id) or {}

    for _, item in ipairs(items) do
        if item.item_name == definition.name and metadataEquals(item.metadata, metadata) and item.amount < definition.max_stack then
            return item
        end
    end

    return nil
end

local function makeInstanceId(itemName)
    return ('%s:%s:%s:%s'):format(itemName, os.time(), GetGameTimer and GetGameTimer() or 0, math.random(100000, 999999))
end

local function acquireLocks(inventoryIds, operation, context)
    local ids = {}
    local seen = {}

    for _, id in ipairs(inventoryIds) do
        id = normalizeId(id)

        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end

    table.sort(ids)
    local token = context.correlation_id or correlationId()
    local expiresAt = (GetGameTimer and GetGameTimer() or 0) + NexaInventoryConfig.lockTimeoutMs

    for _, id in ipairs(ids) do
        local existing = Inventory.locks[id]

        if existing and existing.expiresAt > (GetGameTimer and GetGameTimer() or 0) then
            for _, acquired in ipairs(ids) do
                if Inventory.locks[acquired] and Inventory.locks[acquired].token == token then
                    Inventory.locks[acquired] = nil
                end
            end

            return nil, fail(NEXA_INVENTORY_ERRORS.busy, 'Inventory is busy.', {
                inventory_id = id
            })
        end

        Inventory.locks[id] = {
            token = token,
            operation = operation,
            context = context,
            expiresAt = expiresAt
        }
    end

    return {
        ids = ids,
        token = token
    }, nil
end

local function releaseLocks(lock)
    if not lock then
        return
    end

    for _, id in ipairs(lock.ids or {}) do
        if Inventory.locks[id] and Inventory.locks[id].token == lock.token then
            Inventory.locks[id] = nil
        end
    end
end

local function withLocks(inventoryIds, operation, context, callback)
    context = normalizeContext(context, operation)
    local lock, invalid = acquireLocks(inventoryIds, operation, context)

    if invalid then
        return invalid
    end

    local callbackOk, result = pcall(callback, context)
    releaseLocks(lock)

    if not callbackOk then
        log('Error', 'inventory.transaction', 'Inventory operation failed.', {
            operation = operation,
            error = result,
            correlationId = context.correlation_id
        })
        return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Inventory operation failed.')
    end

    return result
end

local function createInventory(definition)
    if type(definition) ~= 'table' then
        return fail(NEXA_INVENTORY_ERRORS.invalidInput, 'Inventory definition is invalid.')
    end

    local inventoryType = normalizeSlug(definition.inventory_type or definition.type, NexaInventoryConfig.maxInventoryTypeLength)
    local ownerType = normalizeSlug(definition.owner_type, NexaInventoryConfig.maxOwnerTypeLength)
    local ownerId = normalizeString(tostring(definition.owner_id or ''), NexaInventoryConfig.maxOwnerIdLength)

    if not inventoryType or not NexaInventoryTypes[inventoryType] then
        return fail(NEXA_INVENTORY_ERRORS.invalidInput, 'Inventory type is invalid.')
    end

    if not ownerType or not NexaInventoryOwnerTypes[ownerType] then
        return fail(NEXA_INVENTORY_ERRORS.invalidInput, 'Owner type is invalid.')
    end

    if not ownerId then
        return fail(NEXA_INVENTORY_ERRORS.invalidInput, 'Owner ID is invalid.')
    end

    local existing, existingErr = NexaInventoryDatabase.GetInventoryByOwner(inventoryType, ownerType, ownerId)

    if existingErr then
        return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Inventory lookup failed.', existingErr)
    end

    if existing then
        return ok(normalizeInventory(existing), 'Inventory already exists.')
    end

    local metadata, invalid = validateMetadata(definition.metadata)

    if invalid then
        return invalid
    end

    local inventoryId, err = NexaInventoryDatabase.InsertInventory({
        inventory_type = inventoryType,
        owner_type = ownerType,
        owner_id = ownerId,
        slot_limit = tonumber(definition.slot_limit) or 0,
        weight_limit = tonumber(definition.weight_limit) or 0,
        current_weight = 0,
        status = definition.status or NEXA_INVENTORY_STATUS.ready,
        metadata = encode(metadata),
        expires_at = definition.expires_at
    })

    if err then
        return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Inventory could not be created.', err)
    end

    local inventory = getInventoryById(inventoryId)
    return ok(inventory, 'Inventory created.')
end

function GetInventory(inventoryIdOrType, ownerType, ownerId)
    if ownerType ~= nil then
        local row, err = NexaInventoryDatabase.GetInventoryByOwner(inventoryIdOrType, ownerType, tostring(ownerId))

        if err then
            return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Inventory lookup failed.', err)
        end

        if not row then
            return fail(NEXA_INVENTORY_ERRORS.notFound, 'Inventory not found.')
        end

        return ok(normalizeInventory(row), 'Inventory loaded.')
    end

    local inventory, invalid = getInventoryById(inventoryIdOrType)

    if invalid then
        return invalid
    end

    return ok(inventory, 'Inventory loaded.')
end

local function getCharacterFromSource(source)
    source = normalizeSource(source)

    if not source then
        return nil
    end

    if GetResourceState('nexa_playerstate') == 'started' then
        local psOk, character = pcall(function()
            return exports.nexa_playerstate:GetActiveCharacter(source)
        end)

        if psOk and type(character) == 'table' then
            return character
        end
    end

    local charOk, result = pcall(function()
        return exports.nexa_characters:GetActiveCharacter(source)
    end)

    if charOk and type(result) == 'table' then
        return result.data and (result.data.character or result.data) or result
    end

    return nil
end

function GetCharacterInventory(characterIdOrSource)
    local source = normalizeSource(characterIdOrSource)
    local characterId = normalizeId(characterIdOrSource)

    if source then
        local character = getCharacterFromSource(source)
        characterId = normalizeId(character and character.id)
    end

    if not characterId then
        return fail(NEXA_INVENTORY_ERRORS.notReady, 'Character is not ready.')
    end

    local row, err = NexaInventoryDatabase.GetInventoryByOwner('character', 'character', tostring(characterId))

    if err then
        return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Character inventory lookup failed.', err)
    end

    if row then
        row = normalizeInventory(row)
        Inventory.loadedByCharacter[characterId] = row.id
        return ok(row, 'Character inventory loaded.')
    end

    local created = createInventory({
        inventory_type = 'character',
        owner_type = 'character',
        owner_id = tostring(characterId),
        slot_limit = NexaInventoryConfig.defaultCharacterSlots,
        weight_limit = NexaInventoryConfig.defaultCharacterWeight,
        metadata = {
            character_id = characterId
        }
    })

    if created.ok then
        Inventory.loadedByCharacter[characterId] = created.data.id
        emit(NEXA_INVENTORY_EVENTS.ready, {
            characterId = characterId,
            inventoryId = created.data.id
        })
    end

    return created
end

function GetItems(inventoryId)
    local inventory, invalid = getInventoryById(inventoryId)

    if invalid then
        return invalid
    end

    local items
    items, invalid = listItems(inventory.id)

    if invalid then
        return invalid
    end

    return ok(items, 'Items loaded.', {
        count = #items
    })
end

function ListInventoryItems(inventoryId)
    return GetItems(inventoryId)
end

function GetItem(inventoryId, itemReference)
    if itemReference == nil then
        local item, err = NexaInventoryDatabase.GetInventoryItem(inventoryId)

        if err then
            return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Item lookup failed.', err)
        end

        if not item then
            return fail(NEXA_INVENTORY_ERRORS.itemNotFound, 'Item not found.')
        end

        return ok(normalizeItem(item), 'Item loaded.')
    end

    local slot = normalizeSlot(itemReference)
    local item, err = NexaInventoryDatabase.GetInventoryItemBySlot(inventoryId, slot)

    if err then
        return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Item lookup failed.', err)
    end

    if not item then
        return fail(NEXA_INVENTORY_ERRORS.slotEmpty, 'Slot is empty.')
    end

    return ok(normalizeItem(item), 'Item loaded.')
end

function CanCarry(inventoryId, itemName, amount, metadata)
    local inventory, invalid = getInventoryById(inventoryId)

    if invalid then
        return invalid
    end

    local definition
    definition, invalid = itemDefinition(itemName)

    if invalid then
        return invalid
    end

    metadata, invalid = validateMetadata(metadata)

    if invalid then
        return invalid
    end

    local canAdd, code, calculated = Weight.CanAdd(inventory, definition, amount, metadata)

    if not canAdd then
        return fail(code, 'Inventory cannot carry item.')
    end

    if not Slots.FindStack(inventory, definition, metadata) and not Slots.FindFree(inventory) then
        return fail(NEXA_INVENTORY_ERRORS.noFreeSlot, 'No free slot.')
    end

    return ok({
        canCarry = true,
        weight = calculated
    }, 'Inventory can carry item.')
end

local function insertOrStack(inventory, definition, amount, metadata, preferredSlot, context)
    local calculated = Weight.CalculateItem(definition, amount, metadata)
    local stack = Slots.FindStack(inventory, definition, metadata)

    if stack then
        local available = definition.max_stack - stack.amount
        local moved = math.min(available, amount)
        local newAmount = stack.amount + moved
        local newWeight = (tonumber(definition.weight) or 0) * newAmount
        local _, err = NexaInventoryDatabase.UpdateInventoryItem(stack.id, {
            amount = newAmount,
            total_weight = newWeight
        })

        if err then
            return nil, fail(NEXA_INVENTORY_ERRORS.databaseError, 'Stack could not be updated.', err)
        end

        if amount == moved then
            Weight.Recalculate(inventory.id)
            return stack.id, nil
        end

        amount = amount - moved
    end

    local slot = preferredSlot

    if slot and not Slots.IsValid(inventory, slot) then
        return nil, fail(NEXA_INVENTORY_ERRORS.slotInvalid, 'Slot is invalid.')
    end

    if slot and Slots.IsOccupied(inventory.id, slot) then
        return nil, fail(NEXA_INVENTORY_ERRORS.slotOccupied, 'Slot is occupied.')
    end

    slot = slot or Slots.FindFree(inventory)

    if not slot then
        return nil, fail(NEXA_INVENTORY_ERRORS.noFreeSlot, 'No free slot.')
    end

    calculated = Weight.CalculateItem(definition, amount, metadata)
    local inventoryItemId, err = NexaInventoryDatabase.InsertInventoryItem({
        inventory_id = inventory.id,
        item_name = definition.name,
        slot = slot,
        amount = amount,
        metadata = encode(metadata),
        unit_weight = calculated.unit,
        total_weight = calculated.total,
        instance_id = definition.stackable and nil or makeInstanceId(definition.name)
    })

    if err then
        return nil, fail(NEXA_INVENTORY_ERRORS.databaseError, 'Item could not be inserted.', err)
    end

    Weight.Recalculate(inventory.id)
    return inventoryItemId, nil
end

function AddItem(inventoryId, itemName, amount, metadata, context)
    if type(inventoryId) == 'table' then
        local payload = inventoryId
        inventoryId = payload.inventory_id
        itemName = payload.item_name
        amount = payload.amount
        metadata = payload.metadata
        context = payload.context or context
    end

    amount = normalizeAmount(amount)

    if not amount then
        return fail(NEXA_INVENTORY_ERRORS.itemAmountInvalid, 'Amount is invalid.')
    end

    context = normalizeContext(context, 'add_item')

    if not context.reason then
        return fail(NEXA_INVENTORY_ERRORS.invalidInput, 'Mutation reason is required.')
    end

    return withLocks({ inventoryId }, 'add_item', context, function(lockContext)
        local inventory, invalid = getInventoryById(inventoryId)

        if invalid then
            audit('add_item', lockContext, invalid, { target_inventory_id = inventoryId, item_name = itemName, amount = amount })
            return invalid
        end

        local definition
        definition, invalid = itemDefinition(itemName)

        if invalid then
            audit('add_item', lockContext, invalid, { target_inventory_id = inventory.id, item_name = itemName, amount = amount })
            return invalid
        end

        metadata, invalid = validateMetadata(metadata)

        if invalid then
            audit('add_item', lockContext, invalid, { target_inventory_id = inventory.id, item_name = definition.name, amount = amount })
            return invalid
        end

        local canAdd, code = Weight.CanAdd(inventory, definition, amount, metadata)

        if not canAdd then
            local result = fail(code, 'Inventory capacity exceeded.')
            audit('add_item', lockContext, result, { target_inventory_id = inventory.id, item_name = definition.name, amount = amount })
            return result
        end

        local itemId
        itemId, invalid = insertOrStack(inventory, definition, amount, metadata, nil, lockContext)

        if invalid then
            audit('add_item', lockContext, invalid, { target_inventory_id = inventory.id, item_name = definition.name, amount = amount })
            return invalid
        end

        local result = ok({ inventory_item_id = itemId }, 'Item added.')
        audit('add_item', lockContext, result, { target_inventory_id = inventory.id, inventory_item_id = itemId, item_name = definition.name, amount = amount })
        emit(NEXA_INVENTORY_EVENTS.itemAdded, { inventoryId = inventory.id, itemName = definition.name, amount = amount })
        return result
    end)
end

function RemoveItem(inventoryId, itemReference, amount, context)
    if type(inventoryId) == 'table' then
        local payload = inventoryId
        inventoryId = payload.inventory_id
        itemReference = payload.inventory_item_id or payload.id or payload.slot
        amount = payload.amount
        context = payload.context or context
    end

    amount = normalizeAmount(amount)

    if not amount then
        return fail(NEXA_INVENTORY_ERRORS.itemAmountInvalid, 'Amount is invalid.')
    end

    context = normalizeContext(context, 'remove_item')

    return withLocks({ inventoryId }, 'remove_item', context, function(lockContext)
        local itemResponse = GetItem(itemReference)
        local item = itemResponse.ok and itemResponse.data or nil

        if not item or item.inventory_id ~= normalizeId(inventoryId) then
            itemResponse = GetItem(inventoryId, itemReference)
            item = itemResponse.ok and itemResponse.data or nil
        end

        if not item then
            audit('remove_item', lockContext, itemResponse, { source_inventory_id = inventoryId, amount = amount })
            return itemResponse
        end

        if item.amount < amount then
            local result = fail(NEXA_INVENTORY_ERRORS.itemAmountInsufficient, 'Amount is insufficient.')
            audit('remove_item', lockContext, result, { source_inventory_id = item.inventory_id, inventory_item_id = item.id, item_name = item.item_name, amount = amount })
            return result
        end

        if item.amount == amount then
            NexaInventoryDatabase.CleanupQuickslotsForItem(item.id)
            local _, err = NexaInventoryDatabase.DeleteInventoryItem(item.id)

            if err then
                return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Item could not be deleted.', err)
            end
        else
            local newAmount = item.amount - amount
            local _, err = NexaInventoryDatabase.UpdateInventoryItem(item.id, {
                amount = newAmount,
                total_weight = item.unit_weight * newAmount
            })

            if err then
                return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Item could not be updated.', err)
            end
        end

        Weight.Recalculate(item.inventory_id)
        local result = ok({ inventory_item_id = item.id, removed = amount }, 'Item removed.')
        audit('remove_item', lockContext, result, { source_inventory_id = item.inventory_id, inventory_item_id = item.id, item_name = item.item_name, amount = amount })
        emit(NEXA_INVENTORY_EVENTS.itemRemoved, { inventoryId = item.inventory_id, itemName = item.item_name, amount = amount })
        return result
    end)
end

function MoveItem(inventoryId, fromSlot, toSlot, amount, context)
    if type(inventoryId) == 'table' then
        local payload = inventoryId
        inventoryId = payload.inventory_id
        fromSlot = payload.from_slot or payload.slot or payload.inventory_item_id
        toSlot = payload.to_slot or payload.target_slot
        amount = payload.amount
        context = payload.context or context
    end

    toSlot = normalizeSlot(toSlot)

    if not toSlot then
        return fail(NEXA_INVENTORY_ERRORS.slotInvalid, 'Target slot is invalid.')
    end

    return withLocks({ inventoryId }, 'move_item', context, function(lockContext)
        local inventory, invalid = getInventoryById(inventoryId)

        if invalid then
            return invalid
        end

        if not Slots.IsValid(inventory, toSlot) then
            return fail(NEXA_INVENTORY_ERRORS.slotInvalid, 'Target slot is invalid.')
        end

        local sourceResponse = GetItem(inventory.id, fromSlot)
        local sourceItem = sourceResponse.ok and sourceResponse.data or nil

        if not sourceItem then
            sourceResponse = GetItem(fromSlot)
            sourceItem = sourceResponse.ok and sourceResponse.data or nil
        end

        if not sourceItem or sourceItem.inventory_id ~= inventory.id then
            return fail(NEXA_INVENTORY_ERRORS.slotEmpty, 'Source item is missing.')
        end

        local targetItem = NexaInventoryDatabase.GetInventoryItemBySlot(inventory.id, toSlot)
        targetItem = normalizeItem(targetItem)

        if targetItem and targetItem.id ~= sourceItem.id then
            NexaInventoryDatabase.UpdateInventoryItem(targetItem.id, { slot = sourceItem.slot })
        end

        local _, err = NexaInventoryDatabase.UpdateInventoryItem(sourceItem.id, { slot = toSlot })

        if err then
            return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Item could not be moved.', err)
        end

        local result = ok({ inventory_item_id = sourceItem.id, slot = toSlot }, 'Item moved.')
        audit('move_item', lockContext, result, { source_inventory_id = inventory.id, inventory_item_id = sourceItem.id, item_name = sourceItem.item_name, amount = sourceItem.amount })
        return result
    end)
end

function TransferItem(sourceInventoryId, targetInventoryId, itemReference, amount, context)
    if type(sourceInventoryId) == 'table' then
        local payload = sourceInventoryId
        sourceInventoryId = payload.source_inventory_id
        targetInventoryId = payload.target_inventory_id
        itemReference = payload.inventory_item_id or payload.item_reference or payload.slot
        amount = payload.amount
        context = payload.context or context
    end

    amount = normalizeAmount(amount)

    if not amount then
        return fail(NEXA_INVENTORY_ERRORS.itemAmountInvalid, 'Amount is invalid.')
    end

    return withLocks({ sourceInventoryId, targetInventoryId }, 'transfer_item', context, function(lockContext)
        local sourceInventory, invalid = getInventoryById(sourceInventoryId)

        if invalid then
            return invalid
        end

        local targetInventory
        targetInventory, invalid = getInventoryById(targetInventoryId)

        if invalid then
            return invalid
        end

        local itemResponse = GetItem(itemReference)
        local item = itemResponse.ok and itemResponse.data or nil

        if not item or item.inventory_id ~= sourceInventory.id then
            itemResponse = GetItem(sourceInventory.id, itemReference)
            item = itemResponse.ok and itemResponse.data or nil
        end

        if not item or item.inventory_id ~= sourceInventory.id then
            return fail(NEXA_INVENTORY_ERRORS.itemNotFound, 'Source item not found.')
        end

        if item.amount < amount then
            return fail(NEXA_INVENTORY_ERRORS.itemAmountInsufficient, 'Amount is insufficient.')
        end

        local definition
        definition, invalid = itemDefinition(item.item_name)

        if invalid then
            return invalid
        end

        local canAdd, code = Weight.CanAdd(targetInventory, definition, amount, item.metadata)

        if not canAdd then
            return fail(code, 'Target cannot carry item.')
        end

        if item.amount == amount then
            local freeSlot = Slots.FindFree(targetInventory)

            if not freeSlot then
                return fail(NEXA_INVENTORY_ERRORS.noFreeSlot, 'Target has no free slot.')
            end

            local _, err = NexaInventoryDatabase.UpdateInventoryItem(item.id, {
                inventory_id = targetInventory.id,
                slot = freeSlot
            })

            if err then
                return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Transfer failed.', err)
            end
        else
            local remaining = item.amount - amount
            local _, updateErr = NexaInventoryDatabase.UpdateInventoryItem(item.id, {
                amount = remaining,
                total_weight = item.unit_weight * remaining
            })

            if updateErr then
                return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Source stack could not be reduced.', updateErr)
            end

            local itemId
            itemId, invalid = insertOrStack(targetInventory, definition, amount, item.metadata, nil, lockContext)

            if invalid then
                NexaInventoryDatabase.UpdateInventoryItem(item.id, {
                    amount = item.amount,
                    total_weight = item.unit_weight * item.amount
                })
                return invalid
            end
        end

        Weight.Recalculate(sourceInventory.id)
        Weight.Recalculate(targetInventory.id)
        local result = ok({ transferred = amount }, 'Item transferred.')
        audit('transfer_item', lockContext, result, {
            source_inventory_id = sourceInventory.id,
            target_inventory_id = targetInventory.id,
            inventory_item_id = item.id,
            item_name = item.item_name,
            amount = amount
        })
        emit(NEXA_INVENTORY_EVENTS.itemTransferred, {
            sourceInventoryId = sourceInventory.id,
            targetInventoryId = targetInventory.id,
            itemName = item.item_name,
            amount = amount
        })
        return result
    end)
end

function HasItem(inventoryId, itemName, amount)
    amount = normalizeAmount(amount or 1)
    itemName = normalizeSlug(itemName, NexaInventoryConfig.maxItemNameLength)

    if not amount or not itemName then
        return fail(NEXA_INVENTORY_ERRORS.invalidInput, 'HasItem input is invalid.')
    end

    local items, invalid = listItems(inventoryId)

    if invalid then
        return invalid
    end

    local total = 0

    for _, item in ipairs(items) do
        if item.item_name == itemName then
            total = total + item.amount
        end
    end

    return ok(total >= amount, 'HasItem checked.', {
        amount = total
    })
end

function GetWeight(inventoryId)
    local inventory, invalid = getInventoryById(inventoryId)

    if invalid then
        return invalid
    end

    return ok({
        current = inventory.current_weight,
        limit = inventory.weight_limit
    }, 'Weight loaded.')
end

function GetLimits(inventoryId)
    local inventory, invalid = getInventoryById(inventoryId)

    if invalid then
        return invalid
    end

    return ok({
        slots = inventory.slot_limit,
        weight = inventory.weight_limit
    }, 'Limits loaded.')
end

function AssignQuickslot(characterId, quickslot, itemReference, context)
    if type(characterId) == 'table' then
        local payload = characterId
        characterId = payload.character_id
        quickslot = payload.quickslot
        itemReference = payload.inventory_item_id
        context = payload.context or context
    end

    characterId = normalizeId(characterId)
    quickslot = normalizeSlot(quickslot)

    if not characterId or not quickslot or quickslot > NexaInventoryConfig.defaultQuickslots then
        return fail(NEXA_INVENTORY_ERRORS.quickslotInvalid, 'Quickslot is invalid.')
    end

    local inventoryResponse = GetCharacterInventory(characterId)

    if not inventoryResponse.ok then
        return inventoryResponse
    end

    local itemResponse = GetItem(itemReference)
    local item = itemResponse.ok and itemResponse.data or nil

    if not item or item.inventory_id ~= inventoryResponse.data.id then
        return fail(NEXA_INVENTORY_ERRORS.quickslotItemInvalid, 'Quickslot item is invalid.')
    end

    local definition = itemDefinition(item.item_name)

    if type(definition) == 'table' and definition.usable ~= true then
        return fail(NEXA_INVENTORY_ERRORS.quickslotItemInvalid, 'Item is not usable.')
    end

    local _, err = NexaInventoryDatabase.AssignQuickslot(characterId, quickslot, item.id)

    if err then
        return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Quickslot could not be assigned.', err)
    end

    local result = ok({ character_id = characterId, quickslot = quickslot, inventory_item_id = item.id }, 'Quickslot assigned.')
    audit('quickslot_assign', context, result, { source_inventory_id = item.inventory_id, inventory_item_id = item.id, item_name = item.item_name })
    return result
end

function ClearQuickslot(characterId, quickslot, context)
    if type(characterId) == 'table' then
        local payload = characterId
        characterId = payload.character_id
        quickslot = payload.quickslot
        context = payload.context or context
    end

    characterId = normalizeId(characterId)
    quickslot = normalizeSlot(quickslot)

    if not characterId or not quickslot or quickslot > NexaInventoryConfig.defaultQuickslots then
        return fail(NEXA_INVENTORY_ERRORS.quickslotInvalid, 'Quickslot is invalid.')
    end

    local _, err = NexaInventoryDatabase.ClearQuickslot(characterId, quickslot)

    if err then
        return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Quickslot could not be cleared.', err)
    end

    local result = ok({ character_id = characterId, quickslot = quickslot }, 'Quickslot cleared.')
    audit('quickslot_clear', context, result, {})
    return result
end

function CreateContainer(itemInstance, definition, context)
    itemInstance = type(itemInstance) == 'table' and itemInstance or { id = itemInstance }
    local instanceId = normalizeString(itemInstance.instance_id or tostring(itemInstance.id or ''), 64)

    if not instanceId then
        return fail(NEXA_INVENTORY_ERRORS.containerNotFound, 'Container instance is invalid.')
    end

    if itemInstance.inventory_type == 'container' or itemInstance.owner_type == 'container_item' then
        return fail(NEXA_INVENTORY_ERRORS.containerNestingForbidden, 'Containers cannot be nested.')
    end

    local result = createInventory({
        inventory_type = 'container',
        owner_type = 'container_item',
        owner_id = instanceId,
        slot_limit = definition and definition.slot_limit or NexaInventoryConfig.defaultContainerSlots,
        weight_limit = definition and definition.weight_limit or NexaInventoryConfig.defaultContainerWeight,
        metadata = {
            item_instance = instanceId
        }
    })
    audit('container_create', context, result, { target_inventory_id = result.ok and result.data.id or nil })
    return result
end

function CreateDrop(sourceInventoryId, itemReference, amount, position, context)
    if type(sourceInventoryId) == 'table' then
        local payload = sourceInventoryId
        sourceInventoryId = payload.source_inventory_id
        itemReference = payload.inventory_item_id or payload.slot
        amount = payload.amount
        position = payload.position
        context = payload.context or context
    end

    amount = normalizeAmount(amount)

    if not amount then
        return fail(NEXA_INVENTORY_ERRORS.itemAmountInvalid, 'Amount is invalid.')
    end

    local metadata = {
        position = position or {},
        ttl = NexaInventoryConfig.defaultDropTtlSeconds
    }
    local dropId = ('drop:%s:%s'):format(os.time(), math.random(100000, 999999))
    local dropInventory = createInventory({
        inventory_type = 'drop',
        owner_type = 'world',
        owner_id = dropId,
        slot_limit = 10,
        weight_limit = 0,
        metadata = metadata
    })

    if not dropInventory.ok then
        return dropInventory
    end

    Inventory.drops[dropInventory.data.id] = {
        id = dropInventory.data.id,
        position = position,
        createdAt = os.time(),
        expiresAt = os.time() + NexaInventoryConfig.defaultDropTtlSeconds
    }

    local transfer = TransferItem(sourceInventoryId, dropInventory.data.id, itemReference, amount, context)

    if not transfer.ok then
        return transfer
    end

    emit(NEXA_INVENTORY_EVENTS.dropCreated, {
        inventoryId = dropInventory.data.id,
        position = position
    })

    return ok(dropInventory.data, 'Drop created.')
end

function ClearInventory(inventoryId, context)
    context = normalizeContext(context, 'clear_inventory')

    return withLocks({ inventoryId }, 'clear_inventory', context, function(lockContext)
        local items, invalid = listItems(inventoryId)

        if invalid then
            return invalid
        end

        for _, item in ipairs(items) do
            NexaInventoryDatabase.CleanupQuickslotsForItem(item.id)
            NexaInventoryDatabase.DeleteInventoryItem(item.id)
        end

        Weight.Recalculate(inventoryId)
        local result = ok({ inventory_id = inventoryId, removed = #items }, 'Inventory cleared.')
        audit('clear_inventory', lockContext, result, { source_inventory_id = inventoryId })
        return result
    end)
end

function SetItemAmount(inventoryItemId, amount, context)
    local itemResponse = GetItem(inventoryItemId)

    if not itemResponse.ok then
        return itemResponse
    end

    local item = itemResponse.data
    local targetAmount = normalizeAmount(amount)

    if not targetAmount then
        return fail(NEXA_INVENTORY_ERRORS.itemAmountInvalid, 'Amount is invalid.')
    end

    local definition, invalid = itemDefinition(item.item_name)

    if invalid then
        return invalid
    end

    if definition.stackable and targetAmount > definition.max_stack then
        return fail(NEXA_INVENTORY_ERRORS.itemStackLimitExceeded, 'Stack limit exceeded.')
    end

    local _, err = NexaInventoryDatabase.UpdateInventoryItem(item.id, {
        amount = targetAmount,
        total_weight = item.unit_weight * targetAmount
    })

    if err then
        return fail(NEXA_INVENTORY_ERRORS.databaseError, 'Item amount could not be set.', err)
    end

    Weight.Recalculate(item.inventory_id)
    local result = ok({ inventory_item_id = item.id, amount = targetAmount }, 'Item amount set.')
    audit('set_item_amount', context, result, { source_inventory_id = item.inventory_id, inventory_item_id = item.id, item_name = item.item_name, amount = targetAmount })
    return result
end

function CheckInventory(inventoryId)
    local items, invalid = listItems(inventoryId)

    if invalid then
        return invalid
    end

    local seenSlots = {}
    local errors = {}
    local weight = 0

    for _, item in ipairs(items) do
        if item.amount < 1 then
            errors[#errors + 1] = 'amount'
        end

        if item.slot then
            if seenSlots[item.slot] then
                errors[#errors + 1] = 'duplicate_slot'
            end

            seenSlots[item.slot] = true
        end

        if item.total_weight < 0 then
            errors[#errors + 1] = 'negative_weight'
        end

        weight = weight + item.total_weight
    end

    if #errors > 0 then
        local result = fail(NEXA_INVENTORY_ERRORS.integrityFailed, 'Inventory integrity failed.', {
            errors = errors
        })
        emit(NEXA_INVENTORY_EVENTS.integrityFailed, { inventoryId = inventoryId, errors = errors })
        return result
    end

    return ok({ inventory_id = inventoryId, weight = weight }, 'Inventory integrity ok.')
end

function RecalculateWeight(inventoryId)
    return Weight.Recalculate(inventoryId)
end

function CreateInventory(payload)
    return createInventory(payload)
end

local function registerCallbacks()
    if GetResourceState('nexa_api') ~= 'started' then
        return
    end

    exports.nexa_api:RegisterServerCallback(NEXA_INVENTORY_CALLBACKS.getInventory, function(source)
        return GetCharacterInventory(source)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_INVENTORY_CALLBACKS.listItems, function(source)
        local inventory = GetCharacterInventory(source)

        if not inventory.ok then
            return inventory
        end

        return GetItems(inventory.data.id)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_INVENTORY_CALLBACKS.moveItem, function(source, payload)
        local inventory = GetCharacterInventory(source)

        if not inventory.ok then
            return inventory
        end

        payload = type(payload) == 'table' and payload or {}
        return MoveItem(inventory.data.id, payload.from_slot, payload.to_slot, payload.amount, {
            source = source,
            reason = 'player_move'
        })
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_INVENTORY_CALLBACKS.assignQuickslot, function(source, payload)
        local character = getCharacterFromSource(source)

        if not character then
            return fail(NEXA_INVENTORY_ERRORS.notReady, 'Character is not ready.')
        end

        payload = type(payload) == 'table' and payload or {}
        return AssignQuickslot(character.id, payload.quickslot, payload.inventory_item_id, {
            source = source,
            reason = 'player_quickslot'
        })
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_INVENTORY_CALLBACKS.clearQuickslot, function(source, payload)
        local character = getCharacterFromSource(source)

        if not character then
            return fail(NEXA_INVENTORY_ERRORS.notReady, 'Character is not ready.')
        end

        payload = type(payload) == 'table' and payload or {}
        return ClearQuickslot(character.id, payload.quickslot, {
            source = source,
            reason = 'player_quickslot_clear'
        })
    end)
end

local function onPlayerReady(payload)
    local source = payload and normalizeSource(payload.source)
    local characterId = payload and normalizeId(payload.characterId)

    if not characterId and source then
        local character = getCharacterFromSource(source)
        characterId = normalizeId(character and character.id)
    end

    if characterId then
        GetCharacterInventory(characterId)
    end
end

local function onPlayerUnloading(payload)
    local characterId = payload and normalizeId(payload.characterId)

    if characterId and Inventory.loadedByCharacter[characterId] then
        emit(NEXA_INVENTORY_EVENTS.unloading, {
            characterId = characterId,
            inventoryId = Inventory.loadedByCharacter[characterId]
        })
        Inventory.loadedByCharacter[characterId] = nil
    end
end

AddEventHandler('nexa:player:ready', onPlayerReady)
AddEventHandler('nexa:player:unloading', onPlayerUnloading)

AddEventHandler('playerDropped', function()
    local character = getCharacterFromSource(source)
    local characterId = normalizeId(character and character.id)

    if characterId then
        Inventory.loadedByCharacter[characterId] = nil
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    Inventory.locks = {}
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if NexaInventoryConfig.autoMigrate then
        local migrateOk, migrateErr = NexaInventoryDatabase.Migrate()
        migrated = migrateOk == true

        if not migrated then
            log('Error', 'inventory.migration', 'Inventory migrations failed.', {
                error = migrateErr
            })
        end
    end

    registerCallbacks()
    log('Info', 'inventory.start', 'nexa_inventory started.', {
        migrated = migrated,
        version = NEXA_INVENTORY.version
    })
end)

exports('GetInventory', GetInventory)
exports('GetCharacterInventory', GetCharacterInventory)
exports('GetItem', GetItem)
exports('GetItems', GetItems)
exports('HasItem', HasItem)
exports('CanCarry', CanCarry)
exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('MoveItem', MoveItem)
exports('TransferItem', TransferItem)
exports('GetWeight', GetWeight)
exports('GetLimits', GetLimits)
exports('AssignQuickslot', AssignQuickslot)
exports('ClearQuickslot', ClearQuickslot)
exports('CreateContainer', CreateContainer)
exports('CreateDrop', CreateDrop)
exports('CreateInventory', CreateInventory)
exports('ListInventoryItems', ListInventoryItems)
exports('SetItemAmount', SetItemAmount)
exports('ClearInventory', ClearInventory)
exports('CheckInventory', CheckInventory)
exports('RecalculateWeight', RecalculateWeight)
exports('getStatus', function()
    return {
        resourceName = NEXA_INVENTORY.resourceName,
        version = NEXA_INVENTORY.version,
        migrated = migrated,
        loadedCharacters = Inventory.loadedByCharacter
    }
end)
exports('getSchema', NexaInventoryDatabase.GetSchema)
