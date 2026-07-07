local cooldowns = {}

local function buildResponse(success, code, message, data, meta, auditId)
    return exports.nexa_api:buildResponse(success, code, message, data, meta, auditId)
end

local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaIllegalCoreConfig.featureFlag)
end

local function getStatus()
    return {
        resourceName = NEXA_ILLEGAL_CORE.resourceName,
        version = NEXA_ILLEGAL_CORE.version,
        api = GetResourceState('nexa_api') == 'started',
        enabled = isEnabled()
    }
end

local function getCooldownKey(characterId, action)
    return ('%s:%s'):format(tostring(characterId), action)
end

local function getCooldownSeconds(action)
    return NexaIllegalCoreServer.cooldowns[action] or NexaIllegalCoreConfig.defaultCooldownSeconds
end

local function checkIllegalCooldown(source, characterId, action)
    local normalizedCharacterId = tonumber(characterId)

    if normalizedCharacterId == nil or normalizedCharacterId <= 0 or math.floor(normalizedCharacterId) ~= normalizedCharacterId then
        return buildResponse(false, 'INVALID_INPUT', 'Ungueltiger Charakter.', nil, nil, nil)
    end

    local bypass = exports.nexa_permissions:has(source, NexaIllegalCoreServer.permissions.cooldownBypass)

    if bypass ~= nil and bypass.success then
        return buildResponse(true, 'OK', 'Cooldown umgangen.', {
            remainingSeconds = 0
        }, nil, nil)
    end

    local normalizedAction = normalizeIllegalAction(action)

    if normalizedAction == nil then
        return buildResponse(false, 'INVALID_INPUT', 'Ungueltige illegale Aktion.', nil, nil, nil)
    end

    local key = getCooldownKey(normalizedCharacterId, normalizedAction)
    local expiresAt = cooldowns[key]
    local now = os.time()

    if expiresAt ~= nil and expiresAt > now then
        return buildResponse(false, 'RATE_LIMITED', 'Diese Aktion ist noch nicht wieder verfuegbar.', {
            remainingSeconds = expiresAt - now
        }, nil, nil)
    end

    return buildResponse(true, 'OK', 'Aktion ist verfuegbar.', {
        remainingSeconds = 0
    }, nil, nil)
end

local function startIllegalCooldown(characterId, action, seconds)
    local normalizedCharacterId = tonumber(characterId)

    if normalizedCharacterId == nil or normalizedCharacterId <= 0 or math.floor(normalizedCharacterId) ~= normalizedCharacterId then
        return buildResponse(false, 'INVALID_INPUT', 'Ungueltiger Charakter.', nil, nil, nil)
    end

    local normalizedAction = normalizeIllegalAction(action)

    if normalizedAction == nil then
        return buildResponse(false, 'INVALID_INPUT', 'Ungueltige illegale Aktion.', nil, nil, nil)
    end

    local duration = tonumber(seconds) or getCooldownSeconds(normalizedAction)

    if duration <= 0 or duration > 86400 then
        return buildResponse(false, 'INVALID_INPUT', 'Ungueltiger Cooldown.', nil, nil, nil)
    end

    cooldowns[getCooldownKey(normalizedCharacterId, normalizedAction)] = os.time() + math.floor(duration)

    return buildResponse(true, 'OK', 'Cooldown wurde gesetzt.', {
        action = normalizedAction,
        durationSeconds = math.floor(duration)
    }, nil, nil)
end

local function getSnapshot(source, payload)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Illegal Core ist deaktiviert.', nil, nil, nil)
    end

    local response = exports.nexa_api['criminal.getReputation'](source, payload or {})

    if response.success then
        exports.nexa_audit:write({
            eventType = 'criminal',
            severity = 'info',
            action = 'illegal_core.snapshot',
            resourceName = NEXA_ILLEGAL_CORE.resourceName,
            metadata = {
                reputationType = payload and payload.reputationType or nil
            }
        })
    end

    return response
end

local function adjustReputation(source, payload)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Illegal Core ist deaktiviert.', nil, nil, nil)
    end

    local cooldown = checkIllegalCooldown(source, payload.characterId, 'illegal.reputation.adjust')

    if not cooldown.success then
        return cooldown
    end

    local response = exports.nexa_api['criminal.adjustReputation'](source, payload)

    if response.success then
        startIllegalCooldown(payload.characterId, 'illegal.reputation.adjust', nil)
    end

    return response
end

local function getBlackmarketCatalog(source, payload)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Illegal Core ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_api['criminal.blackmarketCatalog'](source, payload or {})
end

local function executeBlackmarketTrade(source, payload, catalog, mode)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Illegal Core ist deaktiviert.', nil, nil, nil)
    end

    local characterId = getIllegalActiveCharacterId(source)

    if characterId == nil then
        return buildResponse(false, 'CHARACTER_NOT_LOADED', 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local action = mode == 'sell' and 'blackmarket.sell' or 'blackmarket.buy'
    local cooldown = checkIllegalCooldown(source, characterId, action)

    if not cooldown.success then
        return cooldown
    end

    local request = {}

    for key, value in pairs(payload or {}) do
        request[key] = value
    end

    request.catalog = catalog

    local response = mode == 'sell'
        and exports.nexa_api['criminal.blackmarketSell'](source, request)
        or exports.nexa_api['criminal.blackmarketBuy'](source, request)

    if response.success then
        startIllegalCooldown(characterId, action, nil)
    end

    return response
end

local function buyBlackmarket(source, payload, catalog)
    return executeBlackmarketTrade(source, payload, catalog, 'buy')
end

local function sellBlackmarket(source, payload, catalog)
    return executeBlackmarketTrade(source, payload, catalog, 'sell')
end

local function executeDrugAction(source, payload, configPayload, action, exportName)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Illegal Core ist deaktiviert.', nil, nil, nil)
    end

    local characterId = getIllegalActiveCharacterId(source)

    if characterId == nil then
        return buildResponse(false, 'CHARACTER_NOT_LOADED', 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local cooldown = checkIllegalCooldown(source, characterId, action)

    if not cooldown.success then
        return cooldown
    end

    local request = {}

    for key, value in pairs(payload or {}) do
        request[key] = value
    end

    for key, value in pairs(configPayload or {}) do
        request[key] = value
    end

    local response = exports.nexa_api[exportName](source, request)

    if response.success then
        startIllegalCooldown(characterId, action, nil)
    end

    return response
end

local function plantDrug(source, payload, configPayload)
    return executeDrugAction(source, payload, configPayload, 'drugs.plant', 'criminal.drugsPlant')
end

local function harvestDrug(source, payload, configPayload)
    return executeDrugAction(source, payload, configPayload, 'drugs.harvest', 'criminal.drugsHarvest')
end

local function processDrug(source, payload, configPayload)
    return executeDrugAction(source, payload, configPayload, 'drugs.process', 'criminal.drugsProcess')
end

local function sellDrug(source, payload, configPayload)
    return executeDrugAction(source, payload, configPayload, 'drugs.sell', 'criminal.drugsSell')
end

local function washMoney(source, payload, configPayload)
    return executeDrugAction(source, payload, configPayload, 'moneywash.wash', 'criminal.moneywashWash')
end

local function dismantleChopshop(source, payload, configPayload)
    return executeDrugAction(source, payload, configPayload, 'chopshop.dismantle', 'criminal.chopshopDismantle')
end

local function sellChopshop(source, payload, configPayload)
    return executeDrugAction(source, payload, configPayload, 'chopshop.sell', 'criminal.chopshopSell')
end

local function requestContact(source)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Illegal Core ist deaktiviert.', nil, nil, nil)
    end

    local characterId = getIllegalActiveCharacterId(source)

    if characterId == nil then
        return buildResponse(false, 'CHARACTER_NOT_LOADED', 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local cooldown = checkIllegalCooldown(source, characterId, 'illegal.contact')

    if not cooldown.success then
        return cooldown
    end

    startIllegalCooldown(characterId, 'illegal.contact', nil)

    local auditId = exports.nexa_audit:write({
        eventType = 'criminal',
        severity = 'info',
        actorCharacterId = characterId,
        targetType = 'character',
        targetId = characterId,
        action = 'illegal_core.contactRequested',
        resourceName = NEXA_ILLEGAL_CORE.resourceName,
        metadata = {
            action = 'illegal.contact'
        }
    })

    return buildResponse(true, 'OK', 'Kontakt ist verfuegbar.', {
        action = 'illegal.contact'
    }, nil, auditId and auditId.audit_id or nil)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_ILLEGAL_CORE.resourceName, 'Illegal Core gestartet.', {
        version = NEXA_ILLEGAL_CORE.version,
        featureFlag = NexaIllegalCoreConfig.featureFlag
    })
end)

exports('getStatus', getStatus)
exports('illegal.getSnapshot', getSnapshot)
exports('illegal.adjustReputation', adjustReputation)
exports('illegal.checkCooldown', checkIllegalCooldown)
exports('illegal.startCooldown', startIllegalCooldown)
exports('illegal.requestContact', requestContact)
exports('illegal.blackmarketCatalog', getBlackmarketCatalog)
exports('illegal.blackmarketBuy', buyBlackmarket)
exports('illegal.blackmarketSell', sellBlackmarket)
exports('illegal.drugsPlant', plantDrug)
exports('illegal.drugsHarvest', harvestDrug)
exports('illegal.drugsProcess', processDrug)
exports('illegal.drugsSell', sellDrug)
exports('illegal.moneywashWash', washMoney)
exports('illegal.chopshopDismantle', dismantleChopshop)
exports('illegal.chopshopSell', sellChopshop)
