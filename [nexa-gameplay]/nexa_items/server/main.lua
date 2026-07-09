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
        exports.nexa_logs:info(NEXA_ITEMS.resourceName, message, metadata or {})
        return
    end

    print(('[%s] %s'):format(NEXA_ITEMS.resourceName, message))
end

local function logError(message, metadata)
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:error(NEXA_ITEMS.resourceName, message, metadata or {})
        return
    end

    print(('[%s] ERROR: %s'):format(NEXA_ITEMS.resourceName, message))
end

local function runMigrations()
    if not NexaItemsConfig.autoMigrate then
        logInfo('Nexa Items gestartet, Migrationen sind deaktiviert.', {
            version = NEXA_ITEMS.version
        })
        return
    end

    local ok, errorMessage = NexaItemsDatabase.Migrate()
    migrated = ok == true

    if migrated then
        logInfo('Nexa Items Foundation gestartet.', {
            version = NEXA_ITEMS.version,
            autoMigrate = true
        })
        return
    end

    logError('Nexa Items Migration fehlgeschlagen.', {
        error = errorMessage
    })
end

local function getStatus()
    return {
        resourceName = NEXA_ITEMS.resourceName,
        version = NEXA_ITEMS.version,
        migrated = migrated,
        itemTypes = NexaItemsAllowedTypes
    }
end

local function isSupportedItemType(itemType)
    return type(itemType) == 'string' and NexaItemsAllowedTypes[itemType] == true
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

local function validateSlug(value, field)
    if not value or value:find('^[a-z0-9_%-]+$') == nil then
        return responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Name muss ein Slug sein.', {
            field = field
        })
    end

    return nil
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

local function encodeJsonField(value, field)
    if value == nil then
        return nil, nil
    end

    if type(value) ~= 'table' then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'JSON-Feld muss eine Tabelle sein.', {
            field = field
        })
    end

    local ok, encoded = pcall(json.encode, value)

    if not ok then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'JSON-Feld konnte nicht serialisiert werden.', {
            field = field,
            error = encoded
        })
    end

    return encoded, nil
end

local function normalizeItemRow(row)
    if type(row) ~= 'table' then
        return row
    end

    for _, field in ipairs({ 'stackable', 'usable', 'tradable', 'droppable', 'enabled' }) do
        if row[field] ~= nil then
            row[field] = row[field] == true or tonumber(row[field]) == 1
        end
    end

    row.metadata = decodeJsonField(row.metadata_json)
    row.use_config = decodeJsonField(row.use_config_json)

    return row
end

local function validateNonNegativeInteger(value, field, defaultValue)
    if value == nil then
        return defaultValue, nil
    end

    value = tonumber(value)

    if not value or value < 0 or value % 1 ~= 0 then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Zahl ist ungueltig.', {
            field = field
        })
    end

    return value, nil
end

local function validatePositiveInteger(value, field, defaultValue)
    if value == nil then
        return defaultValue, nil
    end

    value = tonumber(value)

    if not value or value < 1 or value % 1 ~= 0 then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Zahl ist ungueltig.', {
            field = field
        })
    end

    return value, nil
end

local function validateOptionalBoolean(value, field, defaultValue)
    if value == nil then
        return defaultValue, nil
    end

    if type(value) ~= 'boolean' then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Wert muss boolean sein.', {
            field = field
        })
    end

    return value, nil
end

local function validateIdOrName(idOrName)
    if type(idOrName) == 'number' then
        if idOrName >= 1 and idOrName % 1 == 0 then
            return {
                id = idOrName
            }, nil
        end

        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-ID ist ungueltig.', {
            field = 'id'
        })
    end

    if type(idOrName) == 'string' then
        local normalized = normalizeSlug(idOrName)

        if not normalized then
            return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Name ist ungueltig.', {
                field = 'name'
            })
        end

        local numeric = tonumber(normalized)

        if numeric and numeric >= 1 and numeric % 1 == 0 then
            return {
                id = numeric
            }, nil
        end

        local invalid = validateSlug(normalized, 'name')

        if invalid then
            return nil, invalid
        end

        return {
            name = normalized
        }, nil
    end

    return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Identifier ist ungueltig.', nil)
end

local function getItemRow(idOrName)
    local identifier, invalid = validateIdOrName(idOrName)

    if invalid then
        return nil, invalid
    end

    local ok, item

    if identifier.id then
        ok, item = pcall(NexaItemsDatabase.GetItemById, identifier.id)
    else
        ok, item = pcall(NexaItemsDatabase.GetItemByName, identifier.name)
    end

    if not ok then
        return nil, responseFail(NEXA_ITEMS_ERRORS.databaseError, 'Item konnte nicht geladen werden.', item)
    end

    return normalizeItemRow(item), nil
end

local function requireItem(idOrName)
    local item, invalid = getItemRow(idOrName)

    if invalid then
        return nil, invalid
    end

    if not item then
        return nil, responseFail(NEXA_ITEMS_ERRORS.notFound, 'Item wurde nicht gefunden.', {
            idOrName = idOrName
        })
    end

    return item, nil
end

local function databaseFail(message, details)
    logError(message, details)
    return responseFail(NEXA_ITEMS_ERRORS.databaseError, message, details)
end

local function rejectCallbackRequest(source, callbackName, mutation)
    if GetResourceState('nexa_security') == 'started' then
        if not exports.nexa_security:validateSource(source) then
            return responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Ungueltige Anfrage.', nil)
        end

        local rateLimit = exports.nexa_security:checkRateLimit(source, callbackName)

        if not rateLimit or rateLimit.success ~= true then
            return responseFail('RATE_LIMITED', 'Bitte warte einen Moment.', nil)
        end
    end

    if mutation and NexaItemsConfig.requireAdminPermissionForMutations and GetResourceState('nexa_api') == 'started' then
        local permission = exports.nexa_api:RequirePermission(source, NexaItemsConfig.adminPermission)

        if type(permission) ~= 'table' or permission.ok ~= true then
            return responseFail(NEXA_ITEMS_ERRORS.forbidden, 'Keine Berechtigung.', {
                permission = NexaItemsConfig.adminPermission
            })
        end
    end

    return nil
end

local function validateCreatePayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Payload ist ungueltig.', nil)
    end

    local name = normalizeSlug(payload.name)
    local label = normalizeString(payload.label)
    local itemType = normalizeSlug(payload.item_type)

    if not name then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Name fehlt.', {
            field = 'name'
        })
    end

    local invalid = validateSlug(name, 'name')

    if invalid then
        return nil, invalid
    end

    if #name > NexaItemsConfig.maxNameLength then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Name ist zu lang.', {
            field = 'name',
            max = NexaItemsConfig.maxNameLength
        })
    end

    if not label then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Label fehlt.', {
            field = 'label'
        })
    end

    if #label > NexaItemsConfig.maxLabelLength then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Label ist zu lang.', {
            field = 'label',
            max = NexaItemsConfig.maxLabelLength
        })
    end

    if not isSupportedItemType(itemType) then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidType, 'Item-Typ ist nicht erlaubt.', {
            field = 'item_type',
            value = payload.item_type
        })
    end

    local weight
    weight, invalid = validateNonNegativeInteger(payload.weight, 'weight', NexaItemsConfig.defaultWeight)

    if invalid then
        return nil, invalid
    end

    local maxStack
    maxStack, invalid = validatePositiveInteger(payload.max_stack, 'max_stack', NexaItemsConfig.defaultMaxStack)

    if invalid then
        return nil, invalid
    end

    local metadataJson
    metadataJson, invalid = encodeJsonField(payload.metadata, 'metadata')

    if invalid then
        return nil, invalid
    end

    local useConfigJson
    useConfigJson, invalid = encodeJsonField(payload.use_config, 'use_config')

    if invalid then
        return nil, invalid
    end

    local stackable
    stackable, invalid = validateOptionalBoolean(payload.stackable, 'stackable', NexaItemsConfig.defaultStackable)

    if invalid then
        return nil, invalid
    end

    local usable
    usable, invalid = validateOptionalBoolean(payload.usable, 'usable', NexaItemsConfig.defaultUsable)

    if invalid then
        return nil, invalid
    end

    local tradable
    tradable, invalid = validateOptionalBoolean(payload.tradable, 'tradable', NexaItemsConfig.defaultTradable)

    if invalid then
        return nil, invalid
    end

    local droppable
    droppable, invalid = validateOptionalBoolean(payload.droppable, 'droppable', NexaItemsConfig.defaultDroppable)

    if invalid then
        return nil, invalid
    end

    local enabled
    enabled, invalid = validateOptionalBoolean(payload.enabled, 'enabled', NexaItemsConfig.defaultEnabled)

    if invalid then
        return nil, invalid
    end

    local description = payload.description == nil and nil or normalizeString(payload.description)
    local imageUrl = payload.image_url == nil and nil or normalizeString(payload.image_url)

    if payload.description ~= nil and not description then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Beschreibung muss ein String sein.', {
            field = 'description'
        })
    end

    if payload.image_url ~= nil and not imageUrl then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Image-URL muss ein String sein.', {
            field = 'image_url'
        })
    end

    return {
        name = name,
        label = label,
        description = description,
        item_type = itemType,
        image_url = imageUrl,
        weight = weight,
        stackable = stackable,
        max_stack = maxStack,
        usable = usable,
        tradable = tradable,
        droppable = droppable,
        enabled = enabled,
        metadata_json = metadataJson,
        use_config_json = useConfigJson
    }, nil
end

local function CreateItem(payload)
    local normalized, invalid = validateCreatePayload(payload)

    if invalid then
        return invalid
    end

    local existing, existingError = getItemRow(normalized.name)

    if existingError then
        return existingError
    end

    if existing then
        return responseFail(NEXA_ITEMS_ERRORS.duplicateName, 'Item-Name ist bereits vergeben.', {
            name = normalized.name
        })
    end

    local insertOk, itemId = pcall(NexaItemsDatabase.InsertItem, normalized)

    if not insertOk then
        return databaseFail('Item konnte nicht erstellt werden.', itemId)
    end

    local item, itemError = requireItem(itemId)

    if itemError then
        return itemError
    end

    return responseOk(item, 'Item wurde erstellt.')
end

local function GetItem(idOrName)
    local item, invalid = requireItem(idOrName)

    if invalid then
        return invalid
    end

    return responseOk(item, 'Item wurde geladen.')
end

local function normalizeListFilter(filter)
    if filter == nil then
        return {}, nil
    end

    if type(filter) ~= 'table' then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Filter ist ungueltig.', nil)
    end

    local normalized = {}

    if filter.item_type ~= nil then
        normalized.item_type = normalizeSlug(filter.item_type)

        if not isSupportedItemType(normalized.item_type) then
            return nil, responseFail(NEXA_ITEMS_ERRORS.invalidType, 'Item-Typ ist nicht erlaubt.', {
                field = 'item_type',
                value = filter.item_type
            })
        end
    end

    for _, field in ipairs({ 'enabled', 'usable', 'stackable' }) do
        if filter[field] ~= nil then
            if type(filter[field]) ~= 'boolean' then
                return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Filter muss boolean sein.', {
                    field = field
                })
            end

            normalized[field] = filter[field]
        end
    end

    return normalized, nil
end

local function ListItems(filter)
    local normalizedFilter, invalid = normalizeListFilter(filter)

    if invalid then
        return invalid
    end

    local ok, items = pcall(NexaItemsDatabase.ListItems, normalizedFilter)

    if not ok then
        return databaseFail('Items konnten nicht geladen werden.', items)
    end

    for _, item in ipairs(items or {}) do
        normalizeItemRow(item)
    end

    return responseOk(items or {}, 'Items wurden geladen.', {
        count = #(items or {})
    })
end

local function validateUpdatePayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Payload ist ungueltig.', nil)
    end

    local updates = {}
    local invalid

    if payload.name ~= nil then
        local name = normalizeSlug(payload.name)

        if not name then
            return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Name ist ungueltig.', {
                field = 'name'
            })
        end

        invalid = validateSlug(name, 'name')

        if invalid then
            return nil, invalid
        end

        if #name > NexaItemsConfig.maxNameLength then
            return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Name ist zu lang.', {
                field = 'name',
                max = NexaItemsConfig.maxNameLength
            })
        end

        updates.name = name
    end

    if payload.label ~= nil then
        local label = normalizeString(payload.label)

        if not label then
            return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Label ist ungueltig.', {
                field = 'label'
            })
        end

        if #label > NexaItemsConfig.maxLabelLength then
            return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Item-Label ist zu lang.', {
                field = 'label',
                max = NexaItemsConfig.maxLabelLength
            })
        end

        updates.label = label
    end

    if payload.description ~= nil then
        local description = normalizeString(payload.description)

        if not description then
            return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Beschreibung muss ein String sein.', {
                field = 'description'
            })
        end

        updates.description = description
    end

    if payload.item_type ~= nil then
        local itemType = normalizeSlug(payload.item_type)

        if not isSupportedItemType(itemType) then
            return nil, responseFail(NEXA_ITEMS_ERRORS.invalidType, 'Item-Typ ist nicht erlaubt.', {
                field = 'item_type',
                value = payload.item_type
            })
        end

        updates.item_type = itemType
    end

    if payload.image_url ~= nil then
        local imageUrl = normalizeString(payload.image_url)

        if not imageUrl then
            return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Image-URL muss ein String sein.', {
                field = 'image_url'
            })
        end

        updates.image_url = imageUrl
    end

    if payload.weight ~= nil then
        local weight
        weight, invalid = validateNonNegativeInteger(payload.weight, 'weight', nil)

        if invalid then
            return nil, invalid
        end

        updates.weight = weight
    end

    if payload.max_stack ~= nil then
        local maxStack
        maxStack, invalid = validatePositiveInteger(payload.max_stack, 'max_stack', nil)

        if invalid then
            return nil, invalid
        end

        updates.max_stack = maxStack
    end

    for _, field in ipairs({ 'stackable', 'usable', 'tradable', 'droppable', 'enabled' }) do
        if payload[field] ~= nil then
            if type(payload[field]) ~= 'boolean' then
                return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Wert muss boolean sein.', {
                    field = field
                })
            end

            updates[field] = payload[field] and 1 or 0
        end
    end

    if payload.metadata ~= nil then
        local metadataJson
        metadataJson, invalid = encodeJsonField(payload.metadata, 'metadata')

        if invalid then
            return nil, invalid
        end

        updates.metadata_json = metadataJson
    end

    if payload.use_config ~= nil then
        local useConfigJson
        useConfigJson, invalid = encodeJsonField(payload.use_config, 'use_config')

        if invalid then
            return nil, invalid
        end

        updates.use_config_json = useConfigJson
    end

    if next(updates) == nil then
        return nil, responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Keine Item-Aenderung angegeben.', nil)
    end

    return updates, nil
end

local function UpdateItem(idOrName, payload)
    local current, invalid = requireItem(idOrName)

    if invalid then
        return invalid
    end

    local updates
    updates, invalid = validateUpdatePayload(payload)

    if invalid then
        return invalid
    end

    if updates.name and updates.name ~= current.name then
        local existing, existingError = getItemRow(updates.name)

        if existingError then
            return existingError
        end

        if existing then
            return responseFail(NEXA_ITEMS_ERRORS.duplicateName, 'Item-Name ist bereits vergeben.', {
                name = updates.name
            })
        end
    end

    local updateOk, updateResult = pcall(NexaItemsDatabase.UpdateItem, current.id, updates)

    if not updateOk then
        return databaseFail('Item konnte nicht aktualisiert werden.', updateResult)
    end

    local item, itemError = requireItem(current.id)

    if itemError then
        return itemError
    end

    return responseOk(item, 'Item wurde aktualisiert.')
end

local function SetItemEnabled(idOrName, enabled)
    if type(enabled) ~= 'boolean' then
        return responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Enabled muss boolean sein.', {
            field = 'enabled'
        })
    end

    local current, invalid = requireItem(idOrName)

    if invalid then
        return invalid
    end

    local updateOk, updateResult = pcall(NexaItemsDatabase.SetItemEnabled, current.id, enabled)

    if not updateOk then
        return databaseFail('Item konnte nicht aktualisiert werden.', updateResult)
    end

    local item, itemError = requireItem(current.id)

    if itemError then
        return itemError
    end

    return responseOk(item, 'Item-Status wurde aktualisiert.')
end

local function DeleteItem(idOrName)
    local current, invalid = requireItem(idOrName)

    if invalid then
        return invalid
    end

    local deleteOk, affectedRows = pcall(NexaItemsDatabase.DeleteItem, current.id)

    if not deleteOk then
        return databaseFail('Item konnte nicht geloescht werden.', affectedRows)
    end

    if tonumber(affectedRows) == 0 then
        return responseFail(NEXA_ITEMS_ERRORS.notFound, 'Item wurde nicht gefunden.', {
            id = current.id
        })
    end

    return responseOk({
        id = current.id,
        name = current.name
    }, 'Item wurde geloescht.')
end

local function registerCallbacks()
    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.createItem, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_ITEMS_CALLBACKS.createItem, true)

        if rejected then
            return rejected
        end

        return CreateItem(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.getItem, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_ITEMS_CALLBACKS.getItem, false)

        if rejected then
            return rejected
        end

        local idOrName = type(payload) == 'table' and (payload.id or payload.name) or payload
        return GetItem(idOrName)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.listItems, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_ITEMS_CALLBACKS.listItems, false)

        if rejected then
            return rejected
        end

        return ListItems(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.updateItem, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_ITEMS_CALLBACKS.updateItem, true)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return UpdateItem(payload.id or payload.name, payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.setItemEnabled, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_ITEMS_CALLBACKS.setItemEnabled, true)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_ITEMS_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return SetItemEnabled(payload.id or payload.name, payload.enabled)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_ITEMS_CALLBACKS.deleteItem, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_ITEMS_CALLBACKS.deleteItem, true)

        if rejected then
            return rejected
        end

        local idOrName = type(payload) == 'table' and (payload.id or payload.name) or payload
        return DeleteItem(idOrName)
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
exports('getSchema', NexaItemsDatabase.GetSchema)
exports('isSupportedItemType', isSupportedItemType)
exports('CreateItem', CreateItem)
exports('GetItem', GetItem)
exports('ListItems', ListItems)
exports('UpdateItem', UpdateItem)
exports('SetItemEnabled', SetItemEnabled)
exports('DeleteItem', DeleteItem)
