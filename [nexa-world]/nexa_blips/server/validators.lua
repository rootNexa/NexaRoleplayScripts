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

function validateBlipPayload(blip)
    if type(blip) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(blip.id, 64) == nil
        or normalizeText(blip.label, 64) == nil
        or normalizeText(blip.category or 'dynamic', 32) == nil then
        return false, 'INVALID_INPUT'
    end

    if type(blip.coords) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local x = tonumber(blip.coords.x)
    local y = tonumber(blip.coords.y)
    local z = tonumber(blip.coords.z)

    if x == nil or y == nil or z == nil then
        return false, 'INVALID_INPUT'
    end

    if math.abs(x) > 10000 or math.abs(y) > 10000 or z < -200 or z > 2000 then
        return false, 'INVALID_INPUT'
    end

    if blip.playerId ~= nil or blip.serverId ~= nil or blip.entity ~= nil or blip.netId ~= nil then
        return false, 'INVALID_INPUT'
    end

    if blip.permission ~= nil and normalizeText(blip.permission, 96) == nil then
        return false, 'INVALID_INPUT'
    end

    if blip.job ~= nil and normalizeText(blip.job, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    if blip.faction ~= nil and normalizeText(blip.faction, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
