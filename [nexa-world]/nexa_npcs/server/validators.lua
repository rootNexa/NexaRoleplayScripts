local function normalizeText(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' or #trimmed > maxLength then
        return nil
    end

    return trimmed
end

local function isNumber(value)
    return tonumber(value) ~= nil
end

local function validateCoords(coords)
    if type(coords) ~= 'table' then
        return false
    end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)

    return x ~= nil
        and y ~= nil
        and z ~= nil
        and math.abs(x) <= 10000
        and math.abs(y) <= 10000
        and z >= -200
        and z <= 2000
end

function validateNpcDefinition(npc)
    if type(npc) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(npc.id, 64) == nil
        or normalizeText(npc.label, 96) == nil
        or normalizeText(npc.category or 'interaction', 32) == nil then
        return false, 'INVALID_INPUT'
    end

    if type(npc.ped) ~= 'table'
        or normalizeText(npc.ped.model, 64) == nil
        or not validateCoords(npc.ped.coords)
        or not isNumber(npc.ped.heading or 0.0) then
        return false, 'INVALID_INPUT'
    end

    if type(npc.interaction) ~= 'table'
        or normalizeText(npc.interaction.id, 64) == nil
        or normalizeText(npc.interaction.label, 96) == nil
        or normalizeText(npc.interaction.icon or 'fa-solid fa-comment', 64) == nil
        or normalizeText(npc.interaction.event, 96) == nil
        or not isNumber(npc.interaction.distance or 2.0) then
        return false, 'INVALID_INPUT'
    end

    if npc.permission ~= nil and normalizeText(npc.permission, 96) == nil then
        return false, 'INVALID_INPUT'
    end

    if npc.job ~= nil and normalizeText(npc.job, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    if npc.faction ~= nil and normalizeText(npc.faction, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    if npc.shop ~= nil or npc.quest ~= nil or npc.illegal ~= nil or npc.ai ~= nil or npc.reward ~= nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateInteractionPayload(payload)
    if type(payload) ~= 'table'
        or normalizeText(payload.npcId, 64) == nil
        or normalizeText(payload.interactionId, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
