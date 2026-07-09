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
        exports.nexa_logs:info(NEXA_SHOPS.resourceName, message, metadata or {})
        return
    end

    print(('[%s] %s'):format(NEXA_SHOPS.resourceName, message))
end

local function logError(message, metadata)
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:error(NEXA_SHOPS.resourceName, message, metadata or {})
        return
    end

    print(('[%s] ERROR: %s'):format(NEXA_SHOPS.resourceName, message))
end

local function runMigrations()
    if not NexaShopsConfig.autoMigrate then
        logInfo('Nexa Shops gestartet, Migrationen sind deaktiviert.', {
            version = NEXA_SHOPS.version
        })
        return
    end

    local ok, errorMessage = NexaShopsDatabase.Migrate()
    migrated = ok == true

    if migrated then
        logInfo('Nexa Shops Foundation gestartet.', {
            version = NEXA_SHOPS.version,
            autoMigrate = true
        })
        return
    end

    logError('Nexa Shops Migration fehlgeschlagen.', {
        error = errorMessage
    })
end

local function getStatus()
    return {
        resourceName = NEXA_SHOPS.resourceName,
        version = NEXA_SHOPS.version,
        migrated = migrated,
        shopTypes = NexaShopsAllowedTypes
    }
end

local function isSupportedShopType(shopType)
    return type(shopType) == 'string' and NexaShopsAllowedTypes[shopType] == true
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
        return responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Name muss ein Slug sein.', {
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
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'JSON-Feld muss eine Tabelle sein.', {
            field = field
        })
    end

    local ok, encoded = pcall(json.encode, value)

    if not ok then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'JSON-Feld konnte nicht serialisiert werden.', {
            field = field,
            error = encoded
        })
    end

    return encoded, nil
end

local function normalizeShopRow(row)
    if type(row) ~= 'table' then
        return row
    end

    if row.enabled ~= nil then
        row.enabled = row.enabled == true or tonumber(row.enabled) == 1
    end

    row.location = decodeJsonField(row.location_json)
    row.blip = decodeJsonField(row.blip_json)
    row.npc = decodeJsonField(row.npc_json)
    row.metadata = decodeJsonField(row.metadata_json)

    return row
end

local function normalizeShopItemRow(row)
    if type(row) ~= 'table' then
        return row
    end

    for _, field in ipairs({ 'buyable', 'sellable', 'enabled' }) do
        if row[field] ~= nil then
            row[field] = row[field] == true or tonumber(row[field]) == 1
        end
    end

    row.metadata = decodeJsonField(row.metadata_json)

    return row
end

local function validateIdOrName(idOrName, label)
    if type(idOrName) == 'number' then
        if idOrName >= 1 and idOrName % 1 == 0 then
            return {
                id = idOrName
            }, nil
        end

        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, label .. ' ist ungueltig.', nil)
    end

    if type(idOrName) == 'string' then
        local normalized = normalizeSlug(idOrName)

        if not normalized then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, label .. ' ist ungueltig.', nil)
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

    return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, label .. ' ist ungueltig.', nil)
end

local function validatePositiveInteger(value, field, required)
    if value == nil then
        if required then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'ID fehlt.', {
                field = field
            })
        end

        return nil, nil
    end

    value = tonumber(value)

    if not value or value < 1 or value % 1 ~= 0 then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Zahl ist ungueltig.', {
            field = field
        })
    end

    return value, nil
end

local function validateNonNegativeInteger(value, field, defaultValue)
    if value == nil then
        return defaultValue, nil
    end

    value = tonumber(value)

    if not value or value < 0 or value % 1 ~= 0 then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Zahl ist ungueltig.', {
            field = field
        })
    end

    return value, nil
end

local function validateNullableNonNegativeInteger(value, field)
    if value == nil then
        return nil, nil
    end

    value = tonumber(value)

    if not value or value < 0 or value % 1 ~= 0 then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Zahl ist ungueltig.', {
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
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Wert muss boolean sein.', {
            field = field
        })
    end

    return value, nil
end

local function getShopRow(idOrName)
    local identifier, invalid = validateIdOrName(idOrName, 'Shop-Identifier')

    if invalid then
        return nil, invalid
    end

    local ok, shop

    if identifier.id then
        ok, shop = pcall(NexaShopsDatabase.GetShopById, identifier.id)
    else
        ok, shop = pcall(NexaShopsDatabase.GetShopByName, identifier.name)
    end

    if not ok then
        return nil, responseFail(NEXA_SHOPS_ERRORS.databaseError, 'Shop konnte nicht geladen werden.', shop)
    end

    return normalizeShopRow(shop), nil
end

local function requireShop(idOrName)
    local shop, invalid = getShopRow(idOrName)

    if invalid then
        return nil, invalid
    end

    if not shop then
        return nil, responseFail(NEXA_SHOPS_ERRORS.shopNotFound, 'Shop wurde nicht gefunden.', {
            idOrName = idOrName
        })
    end

    return shop, nil
end

local function getShopItem(id)
    id = tonumber(id)

    if not id or id < 1 or id % 1 ~= 0 then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Item-ID ist ungueltig.', {
            field = 'id'
        })
    end

    local ok, shopItem = pcall(NexaShopsDatabase.GetShopItem, id)

    if not ok then
        return nil, responseFail(NEXA_SHOPS_ERRORS.databaseError, 'Shop-Item konnte nicht geladen werden.', shopItem)
    end

    return normalizeShopItemRow(shopItem), nil
end

local function requireShopItem(id)
    local shopItem, invalid = getShopItem(id)

    if invalid then
        return nil, invalid
    end

    if not shopItem then
        return nil, responseFail(NEXA_SHOPS_ERRORS.shopItemNotFound, 'Shop-Item wurde nicht gefunden.', {
            id = id
        })
    end

    return shopItem, nil
end

local function databaseFail(message, details)
    logError(message, details)
    return responseFail(NEXA_SHOPS_ERRORS.databaseError, message, details)
end

local function rejectCallbackRequest(source, callbackName, mutation)
    if GetResourceState('nexa_security') == 'started' then
        if not exports.nexa_security:validateSource(source) then
            return responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Ungueltige Anfrage.', nil)
        end

        local rateLimit = exports.nexa_security:checkRateLimit(source, callbackName)

        if not rateLimit or rateLimit.success ~= true then
            return responseFail('RATE_LIMITED', 'Bitte warte einen Moment.', nil)
        end
    end

    if mutation and NexaShopsConfig.requireAdminPermissionForMutations and GetResourceState('nexa_api') == 'started' then
        local permission = exports.nexa_api:RequirePermission(source, NexaShopsConfig.adminPermission)

        if type(permission) ~= 'table' or permission.ok ~= true then
            return responseFail(NEXA_SHOPS_ERRORS.forbidden, 'Keine Berechtigung.', {
                permission = NexaShopsConfig.adminPermission
            })
        end
    end

    return nil
end

local function validateItemExists(itemName)
    if not NexaShopsConfig.validateItemsWhenAvailable or GetResourceState('nexa_items') ~= 'started' then
        return nil
    end

    local ok, itemResponse = pcall(function()
        return exports.nexa_items:GetItem(itemName)
    end)

    if not ok then
        return databaseFail('Item konnte nicht gegen nexa_items geprueft werden.', itemResponse)
    end

    if type(itemResponse) ~= 'table' or itemResponse.success ~= true then
        return responseFail(NEXA_SHOPS_ERRORS.itemNotFound, 'Item wurde in nexa_items nicht gefunden.', {
            item_name = itemName
        })
    end

    return nil
end

local function validateCreateShopPayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Payload ist ungueltig.', nil)
    end

    local name = normalizeSlug(payload.name)
    local label = normalizeString(payload.label)
    local shopType = normalizeSlug(payload.shop_type)

    if not name then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Name fehlt.', {
            field = 'name'
        })
    end

    local invalid = validateSlug(name, 'name')

    if invalid then
        return nil, invalid
    end

    if #name > NexaShopsConfig.maxNameLength then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Name ist zu lang.', {
            field = 'name',
            max = NexaShopsConfig.maxNameLength
        })
    end

    if not label then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Label fehlt.', {
            field = 'label'
        })
    end

    if #label > NexaShopsConfig.maxLabelLength then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Label ist zu lang.', {
            field = 'label',
            max = NexaShopsConfig.maxLabelLength
        })
    end

    if not isSupportedShopType(shopType) then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidType, 'Shop-Typ ist nicht erlaubt.', {
            field = 'shop_type',
            value = payload.shop_type
        })
    end

    local ownerOrganizationId
    ownerOrganizationId, invalid = validatePositiveInteger(payload.owner_organization_id, 'owner_organization_id', false)

    if invalid then
        return nil, invalid
    end

    local enabled
    enabled, invalid = validateOptionalBoolean(payload.enabled, 'enabled', NexaShopsConfig.defaultEnabled)

    if invalid then
        return nil, invalid
    end

    local locationJson
    locationJson, invalid = encodeJsonField(payload.location, 'location')

    if invalid then
        return nil, invalid
    end

    local blipJson
    blipJson, invalid = encodeJsonField(payload.blip, 'blip')

    if invalid then
        return nil, invalid
    end

    local npcJson
    npcJson, invalid = encodeJsonField(payload.npc, 'npc')

    if invalid then
        return nil, invalid
    end

    local metadataJson
    metadataJson, invalid = encodeJsonField(payload.metadata, 'metadata')

    if invalid then
        return nil, invalid
    end

    return {
        name = name,
        label = label,
        shop_type = shopType,
        enabled = enabled,
        owner_organization_id = ownerOrganizationId,
        location_json = locationJson,
        blip_json = blipJson,
        npc_json = npcJson,
        metadata_json = metadataJson
    }, nil
end

local function CreateShop(payload)
    local normalized, invalid = validateCreateShopPayload(payload)

    if invalid then
        return invalid
    end

    local existing, existingError = getShopRow(normalized.name)

    if existingError then
        return existingError
    end

    if existing then
        return responseFail(NEXA_SHOPS_ERRORS.duplicateName, 'Shop-Name ist bereits vergeben.', {
            name = normalized.name
        })
    end

    local insertOk, shopId = pcall(NexaShopsDatabase.InsertShop, normalized)

    if not insertOk then
        return databaseFail('Shop konnte nicht erstellt werden.', shopId)
    end

    local shop, shopError = requireShop(shopId)

    if shopError then
        return shopError
    end

    return responseOk(shop, 'Shop wurde erstellt.')
end

local function GetShop(idOrName)
    local shop, invalid = requireShop(idOrName)

    if invalid then
        return invalid
    end

    return responseOk(shop, 'Shop wurde geladen.')
end

local function normalizeListFilter(filter)
    if filter == nil then
        return {}, nil
    end

    if type(filter) ~= 'table' then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Filter ist ungueltig.', nil)
    end

    local normalized = {}

    if filter.shop_type ~= nil then
        normalized.shop_type = normalizeSlug(filter.shop_type)

        if not isSupportedShopType(normalized.shop_type) then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidType, 'Shop-Typ ist nicht erlaubt.', {
                field = 'shop_type',
                value = filter.shop_type
            })
        end
    end

    if filter.enabled ~= nil then
        if type(filter.enabled) ~= 'boolean' then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Enabled-Filter muss boolean sein.', {
                field = 'enabled'
            })
        end

        normalized.enabled = filter.enabled
    end

    if filter.owner_organization_id ~= nil then
        local ownerOrganizationId, invalid = validatePositiveInteger(filter.owner_organization_id, 'owner_organization_id', false)

        if invalid then
            return nil, invalid
        end

        normalized.owner_organization_id = ownerOrganizationId
    end

    return normalized, nil
end

local function ListShops(filter)
    local normalizedFilter, invalid = normalizeListFilter(filter)

    if invalid then
        return invalid
    end

    local ok, shops = pcall(NexaShopsDatabase.ListShops, normalizedFilter)

    if not ok then
        return databaseFail('Shops konnten nicht geladen werden.', shops)
    end

    for _, shop in ipairs(shops or {}) do
        normalizeShopRow(shop)
    end

    return responseOk(shops or {}, 'Shops wurden geladen.', {
        count = #(shops or {})
    })
end

local function validateUpdateShopPayload(payload)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Payload ist ungueltig.', nil)
    end

    local updates = {}
    local invalid

    if payload.name ~= nil then
        local name = normalizeSlug(payload.name)

        if not name then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Name ist ungueltig.', {
                field = 'name'
            })
        end

        invalid = validateSlug(name, 'name')

        if invalid then
            return nil, invalid
        end

        if #name > NexaShopsConfig.maxNameLength then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Name ist zu lang.', {
                field = 'name',
                max = NexaShopsConfig.maxNameLength
            })
        end

        updates.name = name
    end

    if payload.label ~= nil then
        local label = normalizeString(payload.label)

        if not label then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Label ist ungueltig.', {
                field = 'label'
            })
        end

        if #label > NexaShopsConfig.maxLabelLength then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Label ist zu lang.', {
                field = 'label',
                max = NexaShopsConfig.maxLabelLength
            })
        end

        updates.label = label
    end

    if payload.shop_type ~= nil then
        local shopType = normalizeSlug(payload.shop_type)

        if not isSupportedShopType(shopType) then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidType, 'Shop-Typ ist nicht erlaubt.', {
                field = 'shop_type',
                value = payload.shop_type
            })
        end

        updates.shop_type = shopType
    end

    if payload.enabled ~= nil then
        if type(payload.enabled) ~= 'boolean' then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Enabled muss boolean sein.', {
                field = 'enabled'
            })
        end

        updates.enabled = payload.enabled and 1 or 0
    end

    if payload.owner_organization_id ~= nil then
        local ownerOrganizationId
        ownerOrganizationId, invalid = validatePositiveInteger(payload.owner_organization_id, 'owner_organization_id', false)

        if invalid then
            return nil, invalid
        end

        updates.owner_organization_id = ownerOrganizationId
    end

    for _, field in ipairs({ 'location', 'blip', 'npc', 'metadata' }) do
        if payload[field] ~= nil then
            local encoded
            encoded, invalid = encodeJsonField(payload[field], field)

            if invalid then
                return nil, invalid
            end

            updates[field .. '_json'] = encoded
        end
    end

    if next(updates) == nil then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Keine Shop-Aenderung angegeben.', nil)
    end

    return updates, nil
end

local function UpdateShop(idOrName, payload)
    local current, invalid = requireShop(idOrName)

    if invalid then
        return invalid
    end

    local updates
    updates, invalid = validateUpdateShopPayload(payload)

    if invalid then
        return invalid
    end

    if updates.name and updates.name ~= current.name then
        local existing, existingError = getShopRow(updates.name)

        if existingError then
            return existingError
        end

        if existing then
            return responseFail(NEXA_SHOPS_ERRORS.duplicateName, 'Shop-Name ist bereits vergeben.', {
                name = updates.name
            })
        end
    end

    local updateOk, updateResult = pcall(NexaShopsDatabase.UpdateShop, current.id, updates)

    if not updateOk then
        return databaseFail('Shop konnte nicht aktualisiert werden.', updateResult)
    end

    local shop, shopError = requireShop(current.id)

    if shopError then
        return shopError
    end

    return responseOk(shop, 'Shop wurde aktualisiert.')
end

local function SetShopEnabled(idOrName, enabled)
    if type(enabled) ~= 'boolean' then
        return responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Enabled muss boolean sein.', {
            field = 'enabled'
        })
    end

    local current, invalid = requireShop(idOrName)

    if invalid then
        return invalid
    end

    local updateOk, updateResult = pcall(NexaShopsDatabase.SetShopEnabled, current.id, enabled)

    if not updateOk then
        return databaseFail('Shop konnte nicht aktualisiert werden.', updateResult)
    end

    local shop, shopError = requireShop(current.id)

    if shopError then
        return shopError
    end

    return responseOk(shop, 'Shop-Status wurde aktualisiert.')
end

local function DeleteShop(idOrName)
    local current, invalid = requireShop(idOrName)

    if invalid then
        return invalid
    end

    local deleteOk, affectedRows = pcall(NexaShopsDatabase.DeleteShop, current.id)

    if not deleteOk then
        return databaseFail('Shop konnte nicht geloescht werden.', affectedRows)
    end

    if tonumber(affectedRows) == 0 then
        return responseFail(NEXA_SHOPS_ERRORS.shopNotFound, 'Shop wurde nicht gefunden.', {
            id = current.id
        })
    end

    return responseOk({
        id = current.id,
        name = current.name
    }, 'Shop wurde geloescht.')
end

local function resolveShopId(payload)
    if payload.shop_id ~= nil then
        return requireShop(payload.shop_id)
    end

    if payload.shop_name ~= nil then
        return requireShop(payload.shop_name)
    end

    return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-ID oder Shop-Name fehlt.', {
        fields = { 'shop_id', 'shop_name' }
    })
end

local function validateShopItemPayload(payload, partial)
    if type(payload) ~= 'table' then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Item-Payload ist ungueltig.', nil)
    end

    local updates = {}
    local invalid

    if not partial or payload.item_name ~= nil then
        local itemName = normalizeSlug(payload.item_name)

        if not itemName then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Item-Name fehlt.', {
                field = 'item_name'
            })
        end

        invalid = validateSlug(itemName, 'item_name')

        if invalid then
            return nil, invalid
        end

        invalid = validateItemExists(itemName)

        if invalid then
            return nil, invalid
        end

        updates.item_name = itemName
    end

    if not partial or payload.price ~= nil then
        local price
        price, invalid = validateNonNegativeInteger(payload.price, 'price', NexaShopsConfig.defaultPrice)

        if invalid then
            return nil, invalid
        end

        updates.price = price
    end

    if payload.currency_item ~= nil then
        local currencyItem = normalizeSlug(payload.currency_item)

        if not currencyItem then
            return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Currency-Item ist ungueltig.', {
                field = 'currency_item'
            })
        end

        invalid = validateSlug(currencyItem, 'currency_item')

        if invalid then
            return nil, invalid
        end

        invalid = validateItemExists(currencyItem)

        if invalid then
            return nil, invalid
        end

        updates.currency_item = currencyItem
    end

    for _, field in ipairs({ 'stock', 'max_stock' }) do
        if payload[field] ~= nil then
            local value
            value, invalid = validateNullableNonNegativeInteger(payload[field], field)

            if invalid then
                return nil, invalid
            end

            updates[field] = value
        end
    end

    for _, field in ipairs({ 'buyable', 'sellable', 'enabled' }) do
        if not partial or payload[field] ~= nil then
            local defaultValue = nil

            if not partial then
                if field == 'buyable' then
                    defaultValue = NexaShopsConfig.defaultBuyable
                elseif field == 'sellable' then
                    defaultValue = NexaShopsConfig.defaultSellable
                else
                    defaultValue = NexaShopsConfig.defaultEnabled
                end
            end

            local value
            value, invalid = validateOptionalBoolean(payload[field], field, defaultValue)

            if invalid then
                return nil, invalid
            end

            if value ~= nil then
                updates[field] = value and 1 or 0
            end
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

    if partial and next(updates) == nil then
        return nil, responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Keine Shop-Item-Aenderung angegeben.', nil)
    end

    return updates, nil
end

local function AddShopItem(payload)
    if type(payload) ~= 'table' then
        return responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Shop-Item-Payload ist ungueltig.', nil)
    end

    local shop, invalid = resolveShopId(payload)

    if invalid then
        return invalid
    end

    local normalized
    normalized, invalid = validateShopItemPayload(payload, false)

    if invalid then
        return invalid
    end

    normalized.shop_id = shop.id

    local insertOk, shopItemId = pcall(NexaShopsDatabase.InsertShopItem, normalized)

    if not insertOk then
        return databaseFail('Shop-Item konnte nicht erstellt werden.', shopItemId)
    end

    local shopItem, shopItemError = requireShopItem(shopItemId)

    if shopItemError then
        return shopItemError
    end

    return responseOk(shopItem, 'Shop-Item wurde erstellt.')
end

local function ListShopItems(shopIdOrName)
    local shop, invalid = requireShop(shopIdOrName)

    if invalid then
        return invalid
    end

    local ok, shopItems = pcall(NexaShopsDatabase.ListShopItems, shop.id)

    if not ok then
        return databaseFail('Shop-Items konnten nicht geladen werden.', shopItems)
    end

    for _, shopItem in ipairs(shopItems or {}) do
        normalizeShopItemRow(shopItem)
    end

    return responseOk(shopItems or {}, 'Shop-Items wurden geladen.', {
        count = #(shopItems or {}),
        shop_id = shop.id,
        shop_name = shop.name
    })
end

local function UpdateShopItem(id, payload)
    local current, invalid = requireShopItem(id)

    if invalid then
        return invalid
    end

    local updates
    updates, invalid = validateShopItemPayload(payload, true)

    if invalid then
        return invalid
    end

    local updateOk, updateResult = pcall(NexaShopsDatabase.UpdateShopItem, current.id, updates)

    if not updateOk then
        return databaseFail('Shop-Item konnte nicht aktualisiert werden.', updateResult)
    end

    local shopItem, shopItemError = requireShopItem(current.id)

    if shopItemError then
        return shopItemError
    end

    return responseOk(shopItem, 'Shop-Item wurde aktualisiert.')
end

local function RemoveShopItem(id)
    local current, invalid = requireShopItem(id)

    if invalid then
        return invalid
    end

    local deleteOk, affectedRows = pcall(NexaShopsDatabase.RemoveShopItem, current.id)

    if not deleteOk then
        return databaseFail('Shop-Item konnte nicht entfernt werden.', affectedRows)
    end

    if tonumber(affectedRows) == 0 then
        return responseFail(NEXA_SHOPS_ERRORS.shopItemNotFound, 'Shop-Item wurde nicht gefunden.', {
            id = current.id
        })
    end

    return responseOk({
        id = current.id,
        shop_id = current.shop_id,
        item_name = current.item_name
    }, 'Shop-Item wurde entfernt.')
end

local function registerCallbacks()
    exports.nexa_api:RegisterServerCallback(NEXA_SHOPS_CALLBACKS.createShop, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_SHOPS_CALLBACKS.createShop, true)

        if rejected then
            return rejected
        end

        return CreateShop(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_SHOPS_CALLBACKS.getShop, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_SHOPS_CALLBACKS.getShop, false)

        if rejected then
            return rejected
        end

        local idOrName = type(payload) == 'table' and (payload.id or payload.name) or payload
        return GetShop(idOrName)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_SHOPS_CALLBACKS.listShops, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_SHOPS_CALLBACKS.listShops, false)

        if rejected then
            return rejected
        end

        return ListShops(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_SHOPS_CALLBACKS.updateShop, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_SHOPS_CALLBACKS.updateShop, true)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return UpdateShop(payload.id or payload.name, payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_SHOPS_CALLBACKS.setShopEnabled, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_SHOPS_CALLBACKS.setShopEnabled, true)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return SetShopEnabled(payload.id or payload.name, payload.enabled)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_SHOPS_CALLBACKS.deleteShop, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_SHOPS_CALLBACKS.deleteShop, true)

        if rejected then
            return rejected
        end

        local idOrName = type(payload) == 'table' and (payload.id or payload.name) or payload
        return DeleteShop(idOrName)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_SHOPS_CALLBACKS.addShopItem, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_SHOPS_CALLBACKS.addShopItem, true)

        if rejected then
            return rejected
        end

        return AddShopItem(payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_SHOPS_CALLBACKS.listShopItems, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_SHOPS_CALLBACKS.listShopItems, false)

        if rejected then
            return rejected
        end

        local idOrName = type(payload) == 'table' and (payload.shop_id or payload.shop_name or payload.id or payload.name) or payload
        return ListShopItems(idOrName)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_SHOPS_CALLBACKS.updateShopItem, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_SHOPS_CALLBACKS.updateShopItem, true)

        if rejected then
            return rejected
        end

        if type(payload) ~= 'table' then
            return responseFail(NEXA_SHOPS_ERRORS.invalidInput, 'Payload ist ungueltig.', nil)
        end

        return UpdateShopItem(payload.id, payload)
    end)

    exports.nexa_api:RegisterServerCallback(NEXA_SHOPS_CALLBACKS.removeShopItem, function(source, payload)
        local rejected = rejectCallbackRequest(source, NEXA_SHOPS_CALLBACKS.removeShopItem, true)

        if rejected then
            return rejected
        end

        local id = type(payload) == 'table' and payload.id or payload
        return RemoveShopItem(id)
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
exports('getSchema', NexaShopsDatabase.GetSchema)
exports('isSupportedShopType', isSupportedShopType)
exports('CreateShop', CreateShop)
exports('GetShop', GetShop)
exports('ListShops', ListShops)
exports('UpdateShop', UpdateShop)
exports('SetShopEnabled', SetShopEnabled)
exports('DeleteShop', DeleteShop)
exports('AddShopItem', AddShopItem)
exports('ListShopItems', ListShopItems)
exports('UpdateShopItem', UpdateShopItem)
exports('RemoveShopItem', RemoveShopItem)
