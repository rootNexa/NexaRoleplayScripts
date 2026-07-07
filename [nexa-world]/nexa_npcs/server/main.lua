local npcIndex = {}
local dynamicNpcs = {}

local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaNpcsConfig.featureFlag)
end

local function buildResponse(success, code, message, data, meta, auditId)
    return exports.nexa_api:buildResponse(success, code, message, data, meta, auditId)
end

local function writeAudit(action, source, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'world',
        severity = 'info',
        action = action,
        resourceName = NEXA_NPCS.resourceName,
        metadata = metadata or {
            source = source
        }
    })

    return result and result.audit_id or nil
end

local function hasPermission(source, permission)
    if permission == nil then
        return true
    end

    local result = exports.nexa_api['permission.has'](source, permission)

    return result == true or (type(result) == 'table' and result.success == true)
end

local function hasJob(source, jobName)
    if jobName == nil then
        return true
    end

    local result = exports.nexa_api['job.getCharacter'](source, {})

    return type(result) == 'table'
        and result.success == true
        and result.data ~= nil
        and result.data.job ~= nil
        and result.data.job.job_name == jobName
end

local function hasFaction(source, factionName)
    if factionName == nil then
        return true
    end

    local result = exports.nexa_api['faction.getCurrent'](source, {
        factionName = factionName
    })

    return type(result) == 'table'
        and result.success == true
        and result.data ~= nil
        and result.data.membership ~= nil
        and result.data.membership.faction ~= nil
        and result.data.membership.faction.name == factionName
end

local function canAccessNpc(source, npc)
    return hasPermission(source, npc.permission)
        and hasJob(source, npc.job)
        and hasFaction(source, npc.faction)
end

local function sanitizeNpc(npc)
    return {
        id = npc.id,
        label = npc.label,
        category = npc.category or 'interaction',
        ped = {
            model = npc.ped.model,
            coords = {
                x = tonumber(npc.ped.coords.x),
                y = tonumber(npc.ped.coords.y),
                z = tonumber(npc.ped.coords.z)
            },
            heading = tonumber(npc.ped.heading) or 0.0,
            scenario = npc.ped.scenario
        },
        target = {
            label = npc.interaction.label,
            icon = npc.interaction.icon or 'fa-solid fa-comment',
            event = npc.interaction.event,
            distance = tonumber(npc.interaction.distance) or 2.0
        },
        interactionId = npc.interaction.id
    }
end

local function rebuildNpcIndex()
    npcIndex = {}

    for _, npc in ipairs(NexaNpcsServer.npcs) do
        local valid = validateNpcDefinition(npc)

        if valid then
            npcIndex[npc.id] = npc
        else
            exports.nexa_logs:warn(NEXA_NPCS.resourceName, 'Ungueltiger NPC-Registry-Eintrag.', {
                id = npc.id
            })
        end
    end

    for _, npc in pairs(dynamicNpcs) do
        npcIndex[npc.id] = npc
    end
end

local function collectAllowedNpcs(source)
    local npcs = {}

    for _, npc in ipairs(NexaNpcsServer.npcs) do
        if canAccessNpc(source, npc) then
            npcs[#npcs + 1] = sanitizeNpc(npc)
        end

        if #npcs >= NexaNpcsServer.maxClientNpcs then
            return npcs
        end
    end

    for _, npc in pairs(dynamicNpcs) do
        if canAccessNpc(source, npc) then
            npcs[#npcs + 1] = sanitizeNpc(npc)
        end

        if #npcs >= NexaNpcsServer.maxClientNpcs then
            return npcs
        end
    end

    return npcs
end

local function getStatus()
    local count = 0

    for _ in pairs(npcIndex) do
        count = count + 1
    end

    return {
        resourceName = NEXA_NPCS.resourceName,
        version = NEXA_NPCS.version,
        enabled = isEnabled(),
        npcCount = count
    }
end

local function getAvailable(source)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'NPC-Registry ist deaktiviert.', nil, nil, nil)
    end

    local npcs = collectAllowedNpcs(source)

    exports.nexa_logs:info(NEXA_NPCS.resourceName, 'NPC-Registry wurde serverseitig gefiltert.', {
        source = source,
        count = #npcs
    })

    return buildResponse(true, 'OK', 'NPC-Registry wurde geladen.', {
        npcs = npcs
    }, nil, nil)
end

local function validateInteraction(source, payload)
    if not isEnabled() then
        return buildResponse(false, 'RESOURCE_UNAVAILABLE', 'NPC-Registry ist deaktiviert.', nil, nil, nil)
    end

    local valid, code = validateInteractionPayload(payload)

    if not valid then
        return buildResponse(false, code, 'Ungueltige Interaktionsanfrage.', nil, nil, nil)
    end

    local npc = npcIndex[payload.npcId]

    if npc == nil or npc.interaction.id ~= payload.interactionId then
        return buildResponse(false, 'NOT_FOUND', 'Interaktion wurde nicht gefunden.', nil, nil, nil)
    end

    if not canAccessNpc(source, npc) then
        return buildResponse(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    local auditId = nil

    if npc.interaction.critical == true or npc.permission ~= nil or npc.job ~= nil or npc.faction ~= nil then
        auditId = writeAudit('npcs.interaction.validated', source, {
            npcId = payload.npcId,
            interactionId = payload.interactionId
        })
    end

    exports.nexa_logs:info(NEXA_NPCS.resourceName, 'NPC-Interaktion serverseitig validiert.', {
        source = source,
        npcId = payload.npcId,
        interactionId = payload.interactionId
    })

    return buildResponse(true, 'OK', 'Interaktion wurde validiert.', {
        npcId = payload.npcId,
        interactionId = payload.interactionId,
        allowed = true
    }, nil, auditId)
end

local function registerNpc(npc)
    local valid, code = validateNpcDefinition(npc)

    if not valid then
        return buildResponse(false, code, 'Ungueltige NPC-Daten.', nil, nil, nil)
    end

    dynamicNpcs[npc.id] = npc
    rebuildNpcIndex()

    local auditId = writeAudit('npcs.registry.register', 0, {
        npcId = npc.id,
        category = npc.category
    })

    return buildResponse(true, 'OK', 'NPC wurde registriert.', {
        npcId = npc.id
    }, nil, auditId)
end

local function removeNpc(npcId)
    if type(npcId) ~= 'string' or dynamicNpcs[npcId] == nil then
        return buildResponse(false, 'NOT_FOUND', 'NPC wurde nicht gefunden.', nil, nil, nil)
    end

    dynamicNpcs[npcId] = nil
    rebuildNpcIndex()

    local auditId = writeAudit('npcs.registry.remove', 0, {
        npcId = npcId
    })

    return buildResponse(true, 'OK', 'NPC wurde entfernt.', {
        npcId = npcId
    }, nil, auditId)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    rebuildNpcIndex()

    exports.nexa_logs:info(NEXA_NPCS.resourceName, 'NPC-Registry gestartet.', {
        version = NEXA_NPCS.version,
        featureFlag = NexaNpcsConfig.featureFlag
    })
end)

rebuildNpcIndex()

exports('getStatus', getStatus)
exports('npcs.getAvailable', getAvailable)
exports('npcs.validateInteraction', validateInteraction)
exports('npcs.registerNpc', registerNpc)
exports('npcs.removeNpc', removeNpc)
