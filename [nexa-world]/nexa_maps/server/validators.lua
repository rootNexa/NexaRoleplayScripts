local validAssetTypes = {
    ymap = true,
    ytyp = true,
    mlo = true,
    manifest = true
}

local validLoadStates = {
    planned = true,
    registered = true,
    loaded = true,
    disabled = true,
    error = true
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

local function validateEnvironment(environment)
    if type(environment) ~= 'table' then
        return false
    end

    return normalizeText(environment.weatherProfile or 'default_san_andreas', 64) ~= nil
        and normalizeText(environment.timecycleProfile or 'default', 64) ~= nil
end

local function validateFiles(files)
    if type(files) ~= 'table' or #files < 1 then
        return false
    end

    for _, fileName in ipairs(files) do
        local normalized = normalizeText(fileName, 128)

        if normalized == nil then
            return false
        end

        if normalized:match('%.ydr$') or normalized:match('%.yft$') or normalized:match('%.ytd$') then
            return false
        end
    end

    return true
end

function validateMapEntry(entry)
    if type(entry) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(entry.id, 64) == nil
        or normalizeText(entry.label, 96) == nil
        or normalizeText(entry.category, 64) == nil
        or normalizeText(entry.resourceName, 96) == nil
        or validAssetTypes[entry.assetType] ~= true
        or validLoadStates[entry.loadState] ~= true
        or type(entry.active) ~= 'boolean' then
        return false, 'INVALID_INPUT'
    end

    if not validateEnvironment(entry.environment) or not validateFiles(entry.files) then
        return false, 'INVALID_INPUT'
    end

    if entry.brand ~= nil or entry.authorityName ~= nil or entry.gameplay ~= nil or entry.assetData ~= nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateMapQuery(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.category ~= nil and normalizeText(payload.category, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.activeOnly ~= nil and type(payload.activeOnly) ~= 'boolean' then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
