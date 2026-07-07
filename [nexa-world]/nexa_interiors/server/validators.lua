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

local function validatePoint(point)
    return type(point) == 'table'
        and normalizeText(point.id, 64) ~= nil
        and normalizeText(point.label, 80) ~= nil
        and validateCoords(point.coords)
        and (point.heading == nil or isNumber(point.heading))
end

local function validatePoints(points)
    if type(points) ~= 'table' or #points < 1 then
        return false
    end

    for _, point in ipairs(points) do
        if not validatePoint(point) then
            return false
        end
    end

    return true
end

local function validateRegistryLinks(links)
    if links == nil then
        return true
    end

    if type(links) ~= 'table' then
        return false
    end

    for _, key in ipairs({ 'storage', 'garage', 'faction' }) do
        if links[key] ~= nil and normalizeText(links[key], 96) == nil then
            return false
        end
    end

    return true
end

function validateInteriorDefinition(interior)
    if type(interior) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(interior.id, 64) == nil
        or normalizeText(interior.label, 96) == nil
        or normalizeText(interior.type or 'interior', 32) == nil then
        return false, 'INVALID_INPUT'
    end

    if type(interior.mlo) ~= 'table'
        or normalizeText(interior.mlo.registryName, 96) == nil
        or normalizeText(interior.mlo.assetStatus or 'planned', 32) == nil then
        return false, 'INVALID_INPUT'
    end

    if not validatePoints(interior.entryPoints) or not validatePoints(interior.exitPoints) then
        return false, 'INVALID_INPUT'
    end

    if interior.permission ~= nil and normalizeText(interior.permission, 96) == nil then
        return false, 'INVALID_INPUT'
    end

    if interior.doorlock ~= nil and type(interior.doorlock) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if not validateRegistryLinks(interior.links) then
        return false, 'INVALID_INPUT'
    end

    if interior.teleport ~= nil or interior.model ~= nil or interior.brand ~= nil or interior.authorityName ~= nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateInteriorAccessPayload(payload)
    if type(payload) ~= 'table'
        or normalizeText(payload.interiorId, 64) == nil
        or normalizeText(payload.pointId, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.direction ~= 'entry' and payload.direction ~= 'exit' then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
