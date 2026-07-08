local RESOURCE = GetCurrentResourceName()
local CORE_RESOURCE = 'nexa-core'
local PLAYER_TEST_DELAY_MS = 5000
local TEST_PERMISSION = 'nexa.admin'

local function log(level, message, context)
    local suffix = ''

    if context ~= nil then
        suffix = (' %s'):format(json.encode(context))
    end

    print(('[%s] [%s] %s%s'):format(RESOURCE, level, message, suffix))
end

local function isCoreStarted()
    return GetResourceState(CORE_RESOURCE) == 'started'
end

local function callCoreExport(name, ...)
    if not isCoreStarted() then
        return false, 'CORE_NOT_STARTED'
    end

    local args = { ... }
    local ok, result, err = pcall(function()
        local coreExports = exports[CORE_RESOURCE]
        return coreExports[name](coreExports, table.unpack(args))
    end)

    if not ok then
        return false, 'EXPORT_ERROR', result
    end

    return true, result, err
end

local function summarize(value)
    if value == nil then
        return nil
    end

    if type(value) ~= 'table' then
        return value
    end

    return {
        id = value.id,
        source = value.source,
        identifier = value.identifier and '<present>' or nil,
        activeCharacterId = value.activeCharacterId,
        firstName = value.firstName,
        lastName = value.lastName
    }
end

local function logExportResult(name, ok, result, err, detail)
    if ok then
        log('info', ('%s ok'):format(name), {
            result = summarize(result),
            err = err,
            detail = detail
        })
        return
    end

    log('error', ('%s failed'):format(name), {
        err = result,
        detail = err
    })
end

local function testPlayerExports(source, reason)
    source = tonumber(source)

    if not source or source <= 0 then
        log('warn', 'Player export test skipped: invalid source.', {
            source = source,
            reason = reason
        })
        return
    end

    log('info', 'Running player export checks.', {
        source = source,
        reason = reason
    })

    local okIdentifier, identifier, identifierErr = callCoreExport('GetIdentifier', source)
    logExportResult('GetIdentifier', okIdentifier, identifier and '<present>' or nil, identifierErr)

    local okPlayer, player, playerErr = callCoreExport('GetPlayer', source)
    logExportResult('GetPlayer', okPlayer, player, playerErr)

    local okCharacter, character, characterErr = callCoreExport('GetCharacter', source)
    logExportResult('GetCharacter', okCharacter, character, characterErr)

    local okPermission, hasPermission, permissionErr = callCoreExport('HasPermission', source, TEST_PERMISSION)
    logExportResult('HasPermission', okPermission, hasPermission == true, permissionErr, {
        permission = TEST_PERMISSION
    })
end

local function testAllOnlinePlayers(reason)
    local players = GetPlayers()

    if #players == 0 then
        log('info', 'No players online; player export checks skipped.', {
            reason = reason
        })
        return
    end

    for _, playerSource in ipairs(players) do
        testPlayerExports(tonumber(playerSource), reason)
    end
end

local function testResourceExports()
    log('info', 'Checking nexa-core resource state.', {
        state = GetResourceState(CORE_RESOURCE)
    })

    if not isCoreStarted() then
        log('warn', 'nexa-core is not started; export checks will be skipped.')
        return
    end

    local okCore, coreObject, coreErr = callCoreExport('GetCoreObject')
    logExportResult('GetCoreObject', okCore, coreObject and '<present>' or nil, coreErr)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    testResourceExports()
    testAllOnlinePlayers('resource_start')
end)

AddEventHandler('playerJoining', function()
    local playerSource = source

    SetTimeout(PLAYER_TEST_DELAY_MS, function()
        if GetPlayerName(playerSource) == nil then
            log('warn', 'Player export test skipped: player left before delayed check.', {
                source = playerSource
            })
            return
        end

        testPlayerExports(playerSource, 'player_joining_delayed')
    end)
end)

RegisterCommand('nexacoretest', function(source)
    if source ~= 0 then
        local okPermission, hasPermission = callCoreExport('HasPermission', source, TEST_PERMISSION)

        if not okPermission or hasPermission ~= true then
            log('warn', 'Command denied.', {
                source = source,
                permission = TEST_PERMISSION
            })
            return
        end

        testPlayerExports(source, 'command')
        return
    end

    testResourceExports()
    testAllOnlinePlayers('console_command')
end, false)
