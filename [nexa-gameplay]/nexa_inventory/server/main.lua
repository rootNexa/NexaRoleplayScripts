local migrated = false

local function response(success, code, message, data, meta)
    return {
        ok = success == true,
        success = success == true,
        code = code,
        message = message,
        data = data,
        meta = meta,
        error = success == true and nil or {
            code = code,
            message = message,
            details = meta
        }
    }
end

local function responseOk(data, message, meta)
    return response(true, 'OK', message or 'OK', data, meta)
end

local function responseFail(code, message, meta)
    return response(false, code, message, nil, meta)
end

local function logInfo(message, metadata)
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info(NEXA_INVENTORY.resourceName, message, metadata or {})
        return
    end

    print(('[%s] %s'):format(NEXA_INVENTORY.resourceName, message))
end

local function logError(message, metadata)
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:error(NEXA_INVENTORY.resourceName, message, metadata or {})
        return
    end

    print(('[%s] ERROR: %s'):format(NEXA_INVENTORY.resourceName, message))
end

local function runMigrations()
    if not NexaInventoryConfig.autoMigrate then
        logInfo('Nexa Inventory gestartet, Migrationen sind deaktiviert.', {
            version = NEXA_INVENTORY.version
        })
        return
    end

    local ok, errorMessage = NexaInventoryDatabase.Migrate()
    migrated = ok == true

    if migrated then
        logInfo('Nexa Inventory Foundation gestartet.', {
            version = NEXA_INVENTORY.version,
            autoMigrate = true
        })
        return
    end

    logError('Nexa Inventory Migration fehlgeschlagen.', {
        error = errorMessage
    })
end

local function getStatus()
    return {
        resourceName = NEXA_INVENTORY.resourceName,
        version = NEXA_INVENTORY.version,
        migrated = migrated,
        ownerTypes = NexaInventoryAllowedOwnerTypes
    }
end

local function databaseFail(message, details)
    logError(message, details)
    return responseFail(NEXA_INVENTORY_ERRORS.databaseError, message, details)
end

local function normalizeString(value)
    if type(value) ~= 'string' then
        return nil
    end

    local normalized = value:gsub('^%s+', ''):gsub('%s+$', '')

    if normalized == '' then
        return nil
    end

    return normalized
end

local function normalizeSlug(value)
    value = normalizeString(value)

    if not value then
        return nil
    end

    return value:lower()
end

local function isSupportedOwnerType(ownerType)
    return type(ownerType) == 'string' and NexaInventoryAllowedOwnerTypes[ownerType] == true
end

local function validateInteger(value, field, minValue, defaultValue)
    if value == nil then
        return defaultValue, nil
    end

    value = tonumber(value)

    if not value or value < minValue or value % 1 ~= 0 then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'Zahl ist ungueltig.', {
            field = field,
            min = minValue
        })
    end

    return value, nil
end

local function encodeJsonField(value, field)
    if value == nil then
        return nil, nil
    end

    if type(value) ~= 'table' then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'JSON-Feld muss eine Tabelle sein.', {
            field = field
        })
    end

    local ok, encoded = pcall(json.encode, value)

    if not ok then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'JSON-Feld konnte nicht serialisiert werden.', {
            field = field,
            error = encoded
        })
    end

    return encoded, nil
end

local function decodeJsonField(value)
    if type(value) ~= 'string' or value == '' then
        return value
    end

    local ok, decoded = pcall(json.decode, value)

    if ok then
        return decoded
    end

    return value
end

local function normalizeInventoryRow(row)
    if type(row) ~= 'table' then
        return row
    end

    row.metadata = decodeJsonField(row.metadata_json)

    return row
end

local function normalizeInventoryItemRow(row)
    if type(row) ~= 'table' then
        return row
    end

    row.metadata = decodeJsonField(row.metadata_json)

    return row
end

local function rejectCallbackRequest(source, callbackName, mutation)
    if GetResourceState('nexa_security') == 'started' then
        if not exports.nexa_security:validateSource(source) then
            return responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'Ungueltige Anfrage.', nil)
        end

        local rateLimit = exports.nexa_security:checkRateLimit(source, callbackName)

        if not rateLimit or rateLimit.success ~= true then
            return responseFail('RATE_LIMITED', 'Bitte warte einen Moment.', nil)
        end
    end

    if mutation and NexaInventoryConfig.requireAdminPermissionForMutations and GetResourceState('nexa_api') == 'started' then
        local permission = exports.nexa_api:RequirePermission(source, NexaInventoryConfig.adminPermission)

        if type(permission) ~= 'table' or permission.ok ~= true then
            return responseFail(NEXA_INVENTORY_ERRORS.forbidden, 'Keine Berechtigung.', {
                permission = NexaInventoryConfig.adminPermission
            })
        end
    end

    return nil
end

local function validateInventoryId(value, field)
    local id, invalid = validateInteger(value, field or 'inventory_id', 1, nil)

    if invalid then
        return nil, invalid
    end

    return id, nil
end

local function requireInventoryById(inventoryId)
    local id, invalid = validateInventoryId(inventoryId, 'inventory_id')

    if invalid then
        return nil, invalid
    end

    local ok, inventory = pcall(NexaInventoryDatabase.GetInventoryById, id)

    if not ok then
        return nil, databaseFail('Inventar konnte nicht geladen werden.', inventory)
    end

    if not inventory then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.notFound, 'Inventar wurde nicht gefunden.', {
            inventory_id = id
        })
    end

    return normalizeInventoryRow(inventory), nil
end

local function validateOwner(ownerType, ownerId)
    ownerType = normalizeSlug(ownerType)
    ownerId = normalizeString(ownerId)

    if not isSupportedOwnerType(ownerType) then
        return nil, nil, responseFail(NEXA_INVENTORY_ERRORS.invalidOwnerType, 'Owner-Type ist nicht erlaubt.', {
            field = 'owner_type',
            value = ownerType
        })
    end

    if #ownerType > NexaInventoryConfig.maxOwnerTypeLength then
        return nil, nil, responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'Owner-Type ist zu lang.', {
            field = 'owner_type'
        })
    end

    if not ownerId or #ownerId > NexaInventoryConfig.maxOwnerIdLength then
        return nil, nil, responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'Owner-ID ist ungueltig.', {
            field = 'owner_id'
        })
    end

    return ownerType, ownerId, nil
end

local function getInventoryRow(ownerType, ownerId)
    local normalizedOwnerType, normalizedOwnerId, invalid = validateOwner(ownerType, ownerId)

    if invalid then
        return nil, invalid
    end

    local ok, inventory = pcall(NexaInventoryDatabase.GetInventoryByOwner, normalizedOwnerType, normalizedOwnerId)

    if not ok then
        return nil, databaseFail('Inventar konnte nicht geladen werden.', inventory)
    end

    return normalizeInventoryRow(inventory), nil
end

local function requireInventory(ownerType, ownerId)
    local inventory, invalid = getInventoryRow(ownerType, ownerId)

    if invalid then
        return nil, invalid
    end

    if not inventory then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.notFound, 'Inventar wurde nicht gefunden.', {
            owner_type = ownerType,
            owner_id = ownerId
        })
    end

    return inventory, nil
end

local function validateItemName(itemName)
    itemName = normalizeSlug(itemName)

    if not itemName or itemName:find('^[a-z0-9_%-]+$') == nil then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidItem, 'Item-Name ist ungueltig.', {
            field = 'item_name'
        })
    end

    if #itemName > NexaInventoryConfig.maxItemNameLength then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidItem, 'Item-Name ist zu lang.', {
            field = 'item_name'
        })
    end

    if GetResourceState('nexa_items') == 'started' then
        local ok, itemResponse = pcall(function()
            return exports.nexa_items:GetItem(itemName)
        end)

        if not ok then
            return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidItem, 'Item konnte nicht validiert werden.', itemResponse)
        end

        if type(itemResponse) ~= 'table' or itemResponse.success ~= true then
            return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidItem, 'Item existiert nicht.', {
                item_name = itemName
            })
        end
    end

    return itemName, nil
end

local function validateCreateInventoryPayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'Inventar-Payload ist ungueltig.', nil)
    end

    local ownerType, ownerId, invalid = validateOwner(payload.owner_type, payload.owner_id)

    if invalid then
        return nil, invalid
    end

    local label = payload.label == nil and nil or normalizeString(payload.label)

    if payload.label ~= nil and (not label or #label > NexaInventoryConfig.maxLabelLength) then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'Label ist ungueltig.', {
            field = 'label'
        })
    end

    local maxWeight
    maxWeight, invalid = validateInteger(payload.max_weight, 'max_weight', 0, NexaInventoryConfig.defaultMaxWeight)

    if invalid then
        return nil, invalid
    end

    local maxSlots
    maxSlots, invalid = validateInteger(payload.max_slots, 'max_slots', 0, NexaInventoryConfig.defaultMaxSlots)

    if invalid then
        return nil, invalid
    end

    local metadataJson
    metadataJson, invalid = encodeJsonField(payload.metadata, 'metadata')

    if invalid then
        return nil, invalid
    end

    return {
        owner_type = ownerType,
        owner_id = ownerId,
        label = label,
        max_weight = maxWeight,
        max_slots = maxSlots,
        metadata_json = metadataJson
    }, nil
end

local function CreateInventory(payload)
    local normalized, invalid = validateCreateInventoryPayload(payload)

    if invalid then
        return invalid
    end

    local existing, existingError = getInventoryRow(normalized.owner_type, normalized.owner_id)

    if existingError then
        return existingError
    end

    if existing then
        return responseFail(NEXA_INVENTORY_ERRORS.duplicateInventory, 'Inventar existiert bereits.', {
            owner_type = normalized.owner_type,
            owner_id = normalized.owner_id
        })
    end

    local insertOk, inventoryId = pcall(NexaInventoryDatabase.InsertInventory, normalized)

    if not insertOk then
        return databaseFail('Inventar konnte nicht erstellt werden.', inventoryId)
    end

    local inventory, inventoryError = requireInventoryById(inventoryId)

    if inventoryError then
        return inventoryError
    end

    return responseOk(inventory, 'Inventar wurde erstellt.')
end

local function GetInventory(ownerType, ownerId)
    local inventory, invalid = requireInventory(ownerType, ownerId)

    if invalid then
        return invalid
    end

    return responseOk(inventory, 'Inventar wurde geladen.')
end

local function ListInventoryItems(inventoryId)
    local inventory, invalid = requireInventoryById(inventoryId)

    if invalid then
        return invalid
    end

    local ok, items = pcall(NexaInventoryDatabase.ListInventoryItems, inventory.id)

    if not ok then
        return databaseFail('Inventar-Items konnten nicht geladen werden.', items)
    end

    for _, item in ipairs(items or {}) do
        normalizeInventoryItemRow(item)
    end

    return responseOk(items or {}, 'Inventar-Items wurden geladen.', {
        count = #(items or {}),
        inventory_id = inventory.id
    })
end

local function validateAddItemPayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'Item-Payload ist ungueltig.', nil)
    end

    local inventoryId, invalid = validateInventoryId(payload.inventory_id, 'inventory_id')

    if invalid then
        return nil, invalid
    end

    local itemName
    itemName, invalid = validateItemName(payload.item_name)

    if invalid then
        return nil, invalid
    end

    local amount
    amount, invalid = validateInteger(payload.amount, 'amount', 1, NexaInventoryConfig.defaultAmount)

    if invalid then
        return nil, invalid
    end

    local slot
    slot, invalid = validateInteger(payload.slot, 'slot', 1, nil)

    if invalid then
        return nil, invalid
    end

    local metadataJson
    metadataJson, invalid = encodeJsonField(payload.metadata, 'metadata')

    if invalid then
        return nil, invalid
    end

    return {
        inventory_id = inventoryId,
        item_name = itemName,
        slot = slot,
        amount = amount,
        metadata_json = metadataJson
    }, nil
end

local function AddItem(payload)
    local normalized, invalid = validateAddItemPayload(payload)

    if invalid then
        return invalid
    end

    local inventory, inventoryError = requireInventoryById(normalized.inventory_id)

    if inventoryError then
        return inventoryError
    end

    local insertOk, inventoryItemId = pcall(NexaInventoryDatabase.InsertInventoryItem, normalized)

    if not insertOk then
        return databaseFail('Item konnte nicht hinzugefuegt werden.', inventoryItemId)
    end

    local ok, inventoryItem = pcall(NexaInventoryDatabase.GetInventoryItem, inventoryItemId)

    if not ok then
        return databaseFail('Inventar-Item konnte nicht geladen werden.', inventoryItem)
    end

    return responseOk(normalizeInventoryItemRow(inventoryItem), 'Item wurde hinzugefuegt.', {
        inventory_id = inventory.id
    })
end

local function validateRemoveItemPayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'Remove-Payload ist ungueltig.', nil)
    end

    local inventoryItemId, invalid = validateInteger(payload.inventory_item_id or payload.id, 'inventory_item_id', 1, nil)

    if invalid then
        return nil, invalid
    end

    local amount
    amount, invalid = validateInteger(payload.amount, 'amount', 1, NexaInventoryConfig.defaultAmount)

    if invalid then
        return nil, invalid
    end

    return {
        inventory_item_id = inventoryItemId,
        amount = amount
    }, nil
end

local function RemoveItem(payload)
    local normalized, invalid = validateRemoveItemPayload(payload)

    if invalid then
        return invalid
    end

    local ok, inventoryItem = pcall(NexaInventoryDatabase.GetInventoryItem, normalized.inventory_item_id)

    if not ok then
        return databaseFail('Inventar-Item konnte nicht geladen werden.', inventoryItem)
    end

    if not inventoryItem then
        return responseFail(NEXA_INVENTORY_ERRORS.notFound, 'Inventar-Item wurde nicht gefunden.', {
            inventory_item_id = normalized.inventory_item_id
        })
    end

    inventoryItem = normalizeInventoryItemRow(inventoryItem)

    if normalized.amount >= tonumber(inventoryItem.amount) then
        local deleteOk, deleteResult = pcall(NexaInventoryDatabase.DeleteInventoryItem, inventoryItem.id)

        if not deleteOk then
            return databaseFail('Inventar-Item konnte nicht entfernt werden.', deleteResult)
        end

        return responseOk({
            removed = true,
            inventory_item_id = inventoryItem.id
        }, 'Item wurde entfernt.')
    end

    local newAmount = tonumber(inventoryItem.amount) - normalized.amount
    local updateOk, updateResult = pcall(NexaInventoryDatabase.UpdateInventoryItemAmount, inventoryItem.id, newAmount)

    if not updateOk then
        return databaseFail('Inventar-Item konnte nicht reduziert werden.', updateResult)
    end

    local reloadOk, updatedItem = pcall(NexaInventoryDatabase.GetInventoryItem, inventoryItem.id)

    if not reloadOk then
        return databaseFail('Inventar-Item konnte nicht geladen werden.', updatedItem)
    end

    return responseOk(normalizeInventoryItemRow(updatedItem), 'Item-Menge wurde reduziert.')
end

local function SetItemAmount(inventoryItemId, amount)
    local id, invalid = validateInteger(inventoryItemId, 'inventory_item_id', 1, nil)

    if invalid then
        return invalid
    end

    amount, invalid = validateInteger(amount, 'amount', 1, nil)

    if invalid then
        return invalid
    end

    local ok, inventoryItem = pcall(NexaInventoryDatabase.GetInventoryItem, id)

    if not ok then
        return databaseFail('Inventar-Item konnte nicht geladen werden.', inventoryItem)
    end

    if not inventoryItem then
        return responseFail(NEXA_INVENTORY_ERRORS.notFound, 'Inventar-Item wurde nicht gefunden.', {
            inventory_item_id = id
        })
    end

    local updateOk, updateResult = pcall(NexaInventoryDatabase.UpdateInventoryItemAmount, id, amount)

    if not updateOk then
        return databaseFail('Inventar-Item konnte nicht aktualisiert werden.', updateResult)
    end

    local reloadOk, updatedItem = pcall(NexaInventoryDatabase.GetInventoryItem, id)

    if not reloadOk then
        return databaseFail('Inventar-Item konnte nicht geladen werden.', updatedItem)
    end

    return responseOk(normalizeInventoryItemRow(updatedItem), 'Item-Menge wurde gesetzt.')
end

local function validateMoveItemPayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'Move-Payload ist ungueltig.', nil)
    end

    local inventoryItemId, invalid = validateInteger(payload.inventory_item_id or payload.id, 'inventory_item_id', 1, nil)

    if invalid then
        return nil, invalid
    end

    local targetInventoryId
    targetInventoryId, invalid = validateInteger(payload.target_inventory_id or payload.inventory_id, 'target_inventory_id', 1, nil)

    if invalid then
        return nil, invalid
    end

    local slot
    slot, invalid = validateInteger(payload.slot, 'slot', 1, nil)

    if invalid then
        return nil, invalid
    end

    return {
        inventory_item_id = inventoryItemId,
        target_inventory_id = targetInventoryId,
        slot = slot
    }, nil
end

local function MoveItem(payload)
    local normalized, invalid = validateMoveItemPayload(payload)

    if invalid then
        return invalid
    end

    local ok, inventoryItem = pcall(NexaInventoryDatabase.GetInventoryItem, normalized.inventory_item_id)

    if not ok then
        return databaseFail('Inventar-Item konnte nicht geladen werden.', inventoryItem)
    end

    if not inventoryItem then
        return responseFail(NEXA_INVENTORY_ERRORS.notFound, 'Inventar-Item wurde nicht gefunden.', {
            inventory_item_id = normalized.inventory_item_id
        })
    end

    local inventory, inventoryError = requireInventoryById(normalized.target_inventory_id)

    if inventoryError then
        return inventoryError
    end

    local updateOk, updateResult = pcall(NexaInventoryDatabase.UpdateInventoryItemSlot, normalized.inventory_item_id, inventory.id, normalized.slot)

    if not updateOk then
        return databaseFail('Inventar-Item konnte nicht bewegt werden.', updateResult)
    end

    local reloadOk, updatedItem = pcall(NexaInventoryDatabase.GetInventoryItem, normalized.inventory_item_id)

    if not reloadOk then
        return databaseFail('Inventar-Item konnte nicht geladen werden.', updatedItem)
    end

    return responseOk(normalizeInventoryItemRow(updatedItem), 'Item wurde bewegt.')
end

local function ClearInventory(inventoryId)
    local inventory, invalid = requireInventoryById(inventoryId)

    if invalid then
        return invalid
    end

    local ok, affectedRows = pcall(NexaInventoryDatabase.ClearInventory, inventory.id)

    if not ok then
        return databaseFail('Inventar konnte nicht geleert werden.', affectedRows)
    end

    return responseOk({
        inventory_id = inventory.id,
        removed = affectedRows
    }, 'Inventar wurde geleert.')
end

local function registerCallbacks()
    exports.nexa_api:RegisterServerCallback(NEXA_INVENTORY_CALLBACKS.getInventory, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_INVENTORY_CALLBACKS.getInventory, false)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_INVENTORY_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return GetInventory(payload.owner_type, payload.owner_id)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_INVENTORY_CALLBACKS.listItems, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_INVENTORY_CALLBACKS.listItems, false)

        if rejected then
            return rejected
        end

        local inventoryId = type(payload) == 'table' and payload.inventory_id or payload
        return ListInventoryItems(inventoryId)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_INVENTORY_CALLBACKS.addItem, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_INVENTORY_CALLBACKS.addItem, true)

        if rejected then
            return rejected
        end

        return AddItem(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_INVENTORY_CALLBACKS.removeItem, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_INVENTORY_CALLBACKS.removeItem, true)

        if rejected then
            return rejected
        end

        return RemoveItem(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_INVENTORY_CALLBACKS.moveItem, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_INVENTORY_CALLBACKS.moveItem, true)

        if rejected then
            return rejected
        end

        return MoveItem(payload)
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    runMigrations()
    registerCallbacks()
end)

exports('getStatus', getStatus)
exports('getSchema', NexaInventoryDatabase.GetSchema)
exports('isSupportedOwnerType', isSupportedOwnerType)
exports('GetInventory', GetInventory)
exports('CreateInventory', CreateInventory)
exports('ListInventoryItems', ListInventoryItems)
exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('SetItemAmount', SetItemAmount)
exports('MoveItem', MoveItem)
exports('ClearInventory', ClearInventory)
