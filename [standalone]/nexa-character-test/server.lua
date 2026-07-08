local RESOURCE = GetCurrentResourceName()
local CORE_RESOURCE = 'nexa-core'
local CHARACTER_RESOURCE = 'nexa-character'
local ADMIN_PERMISSION = 'nexa.admin'
local DEV_MODE = GetConvar('nexa:environment', 'development') == 'development'

local TEST_CHARACTER = {
    first_name = 'Test',
    last_name = 'Character',
    birthdate = '2000-01-01',
    gender = 'unknown'
}

local function log(level, message, context)
    local suffix = ''

    if context ~= nil then
        suffix = (' %s'):format(json.encode(context))
    end

    print(('[%s] [%s] %s%s'):format(RESOURCE, level, message, suffix))
end

local function isStarted(resourceName)
    return GetResourceState(resourceName) == 'started'
end

local function callExport(resourceName, exportName, ...)
    if not isStarted(resourceName) then
        return false, 'RESOURCE_NOT_STARTED'
    end

    local args = { ... }
    local ok, result, err = pcall(function()
        return exports[resourceName][exportName](table.unpack(args))
    end)

    if not ok then
        return false, 'EXPORT_ERROR', result
    end

    return true, result, err
end

local function summarizeCharacter(character)
    if type(character) ~= 'table' then
        return character
    end

    return {
        id = character.id,
        firstName = character.firstName,
        lastName = character.lastName,
        birthdate = character.birthdate,
        gender = character.gender
    }
end

local function summarizeCharacters(characters)
    local summary = {}

    for _, character in ipairs(characters or {}) do
        summary[#summary + 1] = summarizeCharacter(character)
    end

    return summary
end

local function hasAccess(source)
    source = tonumber(source)

    if source == 0 or DEV_MODE then
        return true
    end

    local ok, result = callExport(CORE_RESOURCE, 'HasPermission', source, ADMIN_PERMISSION)
    return ok and result == true
end

local function resolveSources(source)
    source = tonumber(source)

    if source and source > 0 then
        return { source }
    end

    local sources = {}

    for _, playerSource in ipairs(GetPlayers()) do
        sources[#sources + 1] = tonumber(playerSource)
    end

    return sources
end

local function runForSources(source, actionName, callback)
    if not hasAccess(source) then
        log('warn', 'Command denied.', {
            command = actionName,
            source = source,
            permission = ADMIN_PERMISSION,
            devMode = DEV_MODE
        })
        return
    end

    local sources = resolveSources(source)

    if #sources == 0 then
        log('warn', 'No player source available for character test.', {
            command = actionName
        })
        return
    end

    for _, playerSource in ipairs(sources) do
        callback(playerSource)
    end
end

local function logExportResult(name, source, ok, result, err)
    local normalized = result

    if ok and type(result) == 'table' and type(result.ok) == 'boolean' then
        if result.ok then
            log('info', ('%s ok'):format(name), {
                source = source,
                result = name == 'ListCharacters' and summarizeCharacters(result.data) or summarizeCharacter(result.data),
                raw = result
            })
            return
        end

        log('warn', ('%s returned error'):format(name), {
            source = source,
            error = result.error,
            raw = result
        })
        return
    end

    if ok and err == nil then
        log('info', ('%s ok'):format(name), {
            source = source,
            result = normalized
        })
        return
    end

    log('warn', ('%s returned error'):format(name), {
        source = source,
        ok = ok,
        result = result,
        err = err
    })
end

RegisterCommand('nexacharlist', function(source)
    runForSources(source, 'nexacharlist', function(playerSource)
        local ok, characters, err = callExport(CHARACTER_RESOURCE, 'ListCharacters', playerSource)
        logExportResult('ListCharacters', playerSource, ok, characters, err)
    end)
end, false)

RegisterCommand('nexacharcreate', function(source)
    runForSources(source, 'nexacharcreate', function(playerSource)
        local ok, character, err = callExport(CHARACTER_RESOURCE, 'CreateCharacter', playerSource, TEST_CHARACTER)
        logExportResult('CreateCharacter', playerSource, ok, character, err)
    end)
end, false)

RegisterCommand('nexacharselect', function(source, args)
    runForSources(source, 'nexacharselect', function(playerSource)
        local characterId = tonumber(args and args[1])

        if not characterId or characterId <= 0 then
            log('warn', 'SelectCharacter skipped: invalid character id.', {
                source = playerSource,
                raw = args and args[1] or nil
            })
            return
        end

        local ok, character, err = callExport(CHARACTER_RESOURCE, 'SelectCharacter', playerSource, characterId)
        logExportResult('SelectCharacter', playerSource, ok, character, err)
    end)
end, false)

RegisterCommand('nexacharactive', function(source)
    runForSources(source, 'nexacharactive', function(playerSource)
        local ok, character, err = callExport(CHARACTER_RESOURCE, 'GetActiveCharacter', playerSource)
        logExportResult('GetActiveCharacter', playerSource, ok, character, err)
    end)
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    log('info', 'nexa-character development test resource started.', {
        devMode = DEV_MODE,
        core = GetResourceState(CORE_RESOURCE),
        character = GetResourceState(CHARACTER_RESOURCE)
    })
end)
