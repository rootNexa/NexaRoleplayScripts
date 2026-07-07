local validZoneTypes = {
    box = true,
    sphere = true,
    poly = true
}

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

local function validateSize(size)
    return type(size) == 'table'
        and isNumber(size.x)
        and isNumber(size.y)
        and isNumber(size.z)
        and tonumber(size.x) > 0
        and tonumber(size.y) > 0
        and tonumber(size.z) > 0
end

function validateZoneDefinition(zone)
    if type(zone) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(zone.id, 64) == nil
        or normalizeText(zone.label, 80) == nil
        or normalizeText(zone.category or 'public', 32) == nil
        or validZoneTypes[zone.type] ~= true then
        return false, 'INVALID_INPUT'
    end

    if zone.permission ~= nil and normalizeText(zone.permission, 96) == nil then
        return false, 'INVALID_INPUT'
    end

    if zone.type == 'sphere' then
        if not validateCoords(zone.coords) or not isNumber(zone.radius) or tonumber(zone.radius) <= 0 then
            return false, 'INVALID_INPUT'
        end
    elseif zone.type == 'box' then
        if not validateCoords(zone.coords) or not validateSize(zone.size) then
            return false, 'INVALID_INPUT'
        end
    elseif zone.type == 'poly' then
        if type(zone.points) ~= 'table' or #zone.points < 3 or not isNumber(zone.thickness) or tonumber(zone.thickness) <= 0 then
            return false, 'INVALID_INPUT'
        end

        for _, point in ipairs(zone.points) do
            if not validateCoords(point) then
                return false, 'INVALID_INPUT'
            end
        end
    end

    if zone.npc ~= nil or zone.ped ~= nil or zone.interior ~= nil or zone.map ~= nil or zone.illegal ~= nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateZoneReport(payload)
    if type(payload) ~= 'table' or normalizeText(payload.zoneId, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.transition ~= 'entered' and payload.transition ~= 'left' then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateCriticalZonePayload(payload)
    if type(payload) ~= 'table'
        or normalizeText(payload.zoneId, 64) == nil
        or normalizeText(payload.action, 96) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
