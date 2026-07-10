local RESOURCE = GetCurrentResourceName()
local CORE_RESOURCE = 'nexa-core'
local COMMAND_NAME = 'nexa_test_core_runtime'
local COMMAND_ACE = 'nexa.test.core_runtime'

local function nowMs()
    return GetGameTimer and GetGameTimer() or math.floor(os.clock() * 1000)
end

local function encode(value)
    local ok, encoded = pcall(json.encode, value)
    return ok and encoded or '"<json_error>"'
end

local function log(level, message, context)
    print(('[%s] [%s] %s %s'):format(RESOURCE, level, message, encode(context or {})))
end

local function result(status, code, message, data)
    return {
        status = status,
        code = code,
        message = message,
        data = data
    }
end

local function pass(code, message, data)
    return result('pass', code, message, data)
end

local function fail(code, message, data)
    return result('fail', code, message, data)
end

local function skip(code, message, data)
    return result('skip', code, message, data)
end

local function getCore()
    if GetResourceState(CORE_RESOURCE) ~= 'started' then
        return nil, ('%s is %s'):format(CORE_RESOURCE, GetResourceState(CORE_RESOURCE))
    end

    local ok, core = pcall(function()
        return exports[CORE_RESOURCE]:GetCoreObject()
    end)

    if not ok then
        return nil, tostring(core)
    end

    if type(core) ~= 'table' then
        return nil, 'GetCoreObject did not return a table'
    end

    return core, nil
end

local function callCoreExport(name, ...)
    if GetResourceState(CORE_RESOURCE) ~= 'started' then
        return false, nil, 'CORE_NOT_STARTED'
    end

    local args = { ... }
    local ok, value, err = pcall(function()
        return exports[CORE_RESOURCE][name](exports[CORE_RESOURCE], table.unpack(args))
    end)

    if not ok then
        return false, nil, tostring(value)
    end

    return true, value, err
end

local function waitMs(ms)
    if Wait then
        Wait(ms)
    end
end

local suites = {}

local function addTest(name, callback)
    suites[#suites + 1] = {
        name = name,
        callback = callback
    }
end

addTest('core_readiness', function()
    local core, err = getCore()

    if not core then
        return fail('CORE_UNAVAILABLE', 'nexa-core is not reachable.', { error = err })
    end

    if not core.Lifecycle or type(core.Lifecycle.GetState) ~= 'function' or type(core.Lifecycle.IsReady) ~= 'function' then
        return fail('LIFECYCLE_API_MISSING', 'Lifecycle API is missing from GetCoreObject().')
    end

    local state = core.Lifecycle.GetState()
    local ready = core.Lifecycle.IsReady()

    if state ~= 'ready' or ready ~= true then
        return fail('CORE_NOT_READY', 'Core did not report ready.', {
            state = state,
            ready = ready,
            failureReason = core.Lifecycle.GetFailureReason and core.Lifecycle.GetFailureReason() or nil
        })
    end

    return pass('CORE_READY', 'Core reports ready.', {
        state = state,
        startTimestamp = core.Lifecycle.GetStartTimestamp and core.Lifecycle.GetStartTimestamp() or nil
    })
end)

addTest('database_health', function()
    local core, err = getCore()

    if not core then
        return fail('CORE_UNAVAILABLE', 'nexa-core is not reachable.', { error = err })
    end

    if not core.Database or type(core.Database.IsReady) ~= 'function' or type(core.Database.Scalar) ~= 'function' then
        return fail('DATABASE_API_MISSING', 'Database API is missing from GetCoreObject().')
    end

    if core.Database.IsReady() ~= true then
        return fail('DATABASE_NOT_READY', 'Database layer is not ready.', {
            health = core.Database.GetHealth and core.Database.GetHealth() or nil
        })
    end

    local value, queryErr = core.Database.Scalar('SELECT 1', {}, {
        category = 'runtime_tests.database_health',
        retries = 1,
        timeoutMs = 3000
    })

    if queryErr or tonumber(value) ~= 1 then
        return fail('DATABASE_QUERY_FAILED', 'SELECT 1 failed.', {
            error = queryErr,
            value = value
        })
    end

    local migrationCount, migrationErr = core.Database.Scalar('SELECT COUNT(*) FROM nexa_core_migrations', {}, {
        category = 'runtime_tests.database_migrations',
        retries = 1,
        timeoutMs = 3000
    })

    if migrationErr then
        return fail('MIGRATION_TABLE_UNAVAILABLE', 'Migration table cannot be read.', {
            error = migrationErr
        })
    end

    return pass('DATABASE_READY', 'Database health and migration table are readable.', {
        migrations = tonumber(migrationCount) or migrationCount,
        health = core.Database.GetHealth and core.Database.GetHealth() or nil
    })
end)

addTest('public_exports_defensive', function()
    local exportResults = {}

    local okCore, core = callCoreExport('GetCoreObject')
    exportResults.GetCoreObject = okCore and type(core) == 'table'

    local okPlayer, player = callCoreExport('GetPlayer', -1)
    exportResults.GetPlayerInvalid = okPlayer and player == nil

    local okCharacter, character = callCoreExport('GetCharacter', -1)
    exportResults.GetCharacterInvalid = okCharacter and character == nil

    local okIdentifier, identifier = callCoreExport('GetIdentifier', -1)
    exportResults.GetIdentifierInvalid = okIdentifier and identifier == nil

    local okPermission, hasPermission = callCoreExport('HasPermission', -1, 'nexa.admin.kick')
    exportResults.HasPermissionInvalid = okPermission and hasPermission == false

    local okList, characters, listErr = callCoreExport('ListCharacters', -1)
    exportResults.ListCharactersInvalid = okList and characters == nil and listErr == 'INVALID_SOURCE'

    for name, isOk in pairs(exportResults) do
        if isOk ~= true then
            return fail('EXPORT_DEFENSIVE_CHECK_FAILED', 'A defensive export check failed.', {
                export = name,
                results = exportResults
            })
        end
    end

    return pass('EXPORTS_DEFENSIVE', 'Public exports are reachable and defensive invalid-source checks behaved as expected.', {
        mutatingExports = {
            CreateCharacter = 'skipped: mutates data',
            SelectCharacter = 'skipped: requires real character context',
            UpdateCharacter = 'skipped: mutates data'
        }
    })
end)

addTest('event_bus', function()
    local core, err = getCore()

    if not core then
        return fail('CORE_UNAVAILABLE', 'nexa-core is not reachable.', { error = err })
    end

    if not core.EventBus then
        return fail('EVENTBUS_API_MISSING', 'EventBus API is missing from GetCoreObject().')
    end

    local eventName = 'nexa:internal:runtime_tests:probe'
    local calls = {}
    local subscriptions = {}

    local idLow = core.EventBus.On(eventName, function(payload)
        calls[#calls + 1] = 'low:' .. tostring(payload.value)
    end, { priority = 1, metadata = { suite = RESOURCE } })
    subscriptions[#subscriptions + 1] = idLow

    local idHigh = core.EventBus.On(eventName, function(payload)
        calls[#calls + 1] = 'high:' .. tostring(payload.value)
    end, { priority = 10, metadata = { suite = RESOURCE } })
    subscriptions[#subscriptions + 1] = idHigh

    local idError = core.EventBus.On(eventName, function()
        error('intentional runtime test listener error')
    end, { priority = 5, metadata = { suite = RESOURCE } })
    subscriptions[#subscriptions + 1] = idError

    if type(idLow) ~= 'string' or type(idHigh) ~= 'string' or type(idError) ~= 'string' then
        return fail('EVENTBUS_REGISTER_FAILED', 'EventBus listener registration failed.', {
            ids = subscriptions
        })
    end

    local ok, emitResult = core.EventBus.Emit(eventName, { value = 'one' }, { suite = RESOURCE })

    for _, subscriptionId in ipairs(subscriptions) do
        core.EventBus.Off(subscriptionId)
    end

    local onceCount = 0
    local onceId = core.EventBus.Once(eventName, function()
        onceCount = onceCount + 1
    end)
    core.EventBus.Emit(eventName, {})
    core.EventBus.Emit(eventName, {})
    core.EventBus.Off(onceId)

    if ok ~= false or type(emitResult) ~= 'table' or #emitResult.errors ~= 1 then
        return fail('EVENTBUS_ERROR_ISOLATION_FAILED', 'EventBus did not report the intentional listener error as expected.', {
            ok = ok,
            emitResult = emitResult
        })
    end

    if calls[1] ~= 'high:one' or calls[2] ~= 'low:one' then
        return fail('EVENTBUS_PRIORITY_FAILED', 'EventBus listener priority did not run in expected order.', {
            calls = calls
        })
    end

    if onceCount ~= 1 then
        return fail('EVENTBUS_ONCE_FAILED', 'Once-listener did not run exactly once.', {
            onceCount = onceCount
        })
    end

    return pass('EVENTBUS_OK', 'EventBus registration, priority, once-listener and error isolation passed.')
end)

addTest('cache_runtime', function()
    local core, err = getCore()

    if not core then
        return fail('CORE_UNAVAILABLE', 'nexa-core is not reachable.', { error = err })
    end

    if not core.Cache then
        return fail('CACHE_API_MISSING', 'Cache API is missing from GetCoreObject().')
    end

    local namespace = 'runtime_tests'
    core.Cache.Clear(namespace)

    local setOk, setErr = core.Cache.Set(namespace, 'alpha', { nested = { count = 1 } }, { maxEntries = 4 })

    if not setOk then
        return fail('CACHE_SET_FAILED', 'Cache.Set failed.', { error = setErr })
    end

    local first = core.Cache.Get(namespace, 'alpha')

    if type(first) ~= 'table' or first.nested.count ~= 1 then
        return fail('CACHE_GET_FAILED', 'Cache.Get returned unexpected value.', { value = first })
    end

    first.nested.count = 99
    local second = core.Cache.Get(namespace, 'alpha')

    if second.nested.count ~= 1 then
        return fail('CACHE_CLONE_FAILED', 'Cache value was mutated through caller reference.', { value = second })
    end

    core.Cache.Set(namespace, 'ttl', 'gone-soon', { ttlMs = 10 })
    waitMs(30)

    if core.Cache.Has(namespace, 'ttl') then
        return fail('CACHE_TTL_FAILED', 'TTL entry still exists after expiration.')
    end

    local loaded, loadErr, cached = core.Cache.GetOrLoad(namespace, 'loaded', function()
        return { loaded = true }
    end)

    if loadErr or type(loaded) ~= 'table' or loaded.loaded ~= true or cached ~= false then
        return fail('CACHE_GET_OR_LOAD_FAILED', 'GetOrLoad failed for successful loader.', {
            loaded = loaded,
            error = loadErr,
            cached = cached
        })
    end

    local failedLoad, failedErr = core.Cache.GetOrLoad(namespace, 'failed', function()
        return nil, 'EXPECTED_LOAD_FAILURE'
    end)

    if failedLoad ~= nil or failedErr ~= 'EXPECTED_LOAD_FAILURE' then
        return fail('CACHE_LOADER_ERROR_FAILED', 'Loader errors are not surfaced as expected.', {
            value = failedLoad,
            error = failedErr
        })
    end

    local secretOk, secretErr = core.Cache.Set(namespace, 'secret', 'value', { secret = true })

    if secretOk ~= false or secretErr ~= 'SECRET_CACHE_BLOCKED' then
        return fail('CACHE_SECRET_GUARD_FAILED', 'Secret cache guard did not block secret value.', {
            ok = secretOk,
            error = secretErr
        })
    end

    core.Cache.Clear(namespace)
    return pass('CACHE_OK', 'Cache set/get, clone guard, TTL, GetOrLoad and secret guard passed.', {
        stats = core.Cache.GetStats(namespace)
    })
end)

addTest('callbacks_runtime', function()
    local core, err = getCore()

    if not core then
        return fail('CORE_UNAVAILABLE', 'nexa-core is not reachable.', { error = err })
    end

    if not core.Callbacks then
        return fail('CALLBACK_API_MISSING', 'Callback API is missing from GetCoreObject().')
    end

    local callbackName = 'nexa:runtime_tests:cb:probe'
    local registered, registerErr = core.Callbacks.Register(callbackName, function(payload, context)
        return {
            echoed = payload and payload.value,
            contextPresent = type(context) == 'table'
        }
    end, {
        validate = function(payload)
            return type(payload) == 'table' and type(payload.value) == 'string'
        end
    })

    if not registered then
        return fail('CALLBACK_REGISTER_FAILED', 'Internal callback registration failed.', { error = registerErr })
    end

    local okResponse = core.Callbacks.Call(callbackName, { value = 'hello' }, { suite = RESOURCE })
    local invalidResponse = core.Callbacks.Call(callbackName, { value = 123 }, { suite = RESOURCE })
    local missingResponse = core.Callbacks.Call('nexa:runtime_tests:cb:missing', {}, { suite = RESOURCE })
    core.Callbacks.Unregister(callbackName)

    if okResponse.ok ~= true or okResponse.data.echoed ~= 'hello' or okResponse.data.contextPresent ~= true then
        return fail('CALLBACK_CALL_FAILED', 'Internal callback did not return expected success response.', { response = okResponse })
    end

    if invalidResponse.ok ~= false or invalidResponse.error.code ~= 'INVALID_PAYLOAD' then
        return fail('CALLBACK_VALIDATION_FAILED', 'Invalid payload did not produce expected error response.', { response = invalidResponse })
    end

    if missingResponse.ok ~= false or missingResponse.error.code ~= 'NOT_FOUND' then
        return fail('CALLBACK_NOT_FOUND_FAILED', 'Unknown callback did not produce expected NOT_FOUND response.', { response = missingResponse })
    end

    local networkSession = core.Constants
        and core.Constants.callbacks
        and core.Constants.callbacks.getSession
        and core.Callbacks.Has(core.Constants.callbacks.getSession)

    return pass('CALLBACKS_OK', 'Internal callback registration, validation and unknown callback checks passed.', {
        networkSessionRegistered = networkSession == true,
        serverToClientRoundtrip = 'skipped: requires a connected client'
    })
end)

addTest('sessions_runtime', function()
    local core, err = getCore()

    if not core then
        return fail('CORE_UNAVAILABLE', 'nexa-core is not reachable.', { error = err })
    end

    if not core.Sessions then
        return fail('SESSIONS_API_MISSING', 'Sessions API is missing from GetCoreObject().')
    end

    local activeCount = core.Sessions.GetCount()
    local invalidSession, invalidErr = core.Sessions.Create(-1, { license = 'runtime-invalid' })
    local missingLicense, missingLicenseErr = core.Sessions.Create(999987, { discord = '123456789' })
    local cleanupOk = core.Sessions.Cleanup()

    if type(activeCount) ~= 'number' then
        return fail('SESSION_COUNT_FAILED', 'Session count did not return a number.', { value = activeCount })
    end

    if invalidSession ~= nil or invalidErr ~= 'INVALID_SOURCE' then
        return fail('SESSION_INVALID_SOURCE_FAILED', 'Invalid source was not rejected.', {
            session = invalidSession,
            error = invalidErr
        })
    end

    if missingLicense ~= nil or missingLicenseErr ~= 'MISSING_LICENSE' then
        return fail('SESSION_MISSING_LICENSE_FAILED', 'Missing license was not rejected.', {
            session = missingLicense,
            error = missingLicenseErr
        })
    end

    return pass('SESSIONS_OK', 'Session API defensive checks passed.', {
        activeCount = activeCount,
        cleanup = cleanupOk == true,
        realConnectDrop = 'skipped: requires a connected player'
    })
end)

addTest('permissions_runtime', function()
    local core, err = getCore()

    if not core then
        return fail('CORE_UNAVAILABLE', 'nexa-core is not reachable.', { error = err })
    end

    if not core.Permissions then
        return fail('PERMISSIONS_API_MISSING', 'Permissions API is missing from GetCoreObject().')
    end

    local hasInvalid = core.Permissions.Has(-1, 'nexa.admin.kick')
    local traceInvalid = core.Permissions.GetDecisionTrace(-1, 'nexa.admin.kick')

    if hasInvalid ~= false then
        return fail('PERMISSION_INVALID_SUBJECT_FAILED', 'Invalid permission subject was not denied.', {
            allowed = hasInvalid
        })
    end

    if type(traceInvalid) ~= 'table' or traceInvalid.success ~= false then
        return fail('PERMISSION_TRACE_INVALID_FAILED', 'Invalid decision trace did not return a safe error.', {
            trace = traceInvalid
        })
    end

    return pass('PERMISSIONS_OK', 'Permission invalid-subject checks passed.', {
        mutatingChecks = 'skipped: Grant/Deny/Revoke require an isolated test subject/database'
    })
end)

addTest('modules_runtime', function()
    local core, err = getCore()

    if not core then
        return fail('CORE_UNAVAILABLE', 'nexa-core is not reachable.', { error = err })
    end

    if not core.Modules or type(core.Modules.GetAllStatuses) ~= 'function' then
        return skip('MODULES_API_UNAVAILABLE', 'Module loader is not available.')
    end

    local statuses = core.Modules.GetAllStatuses()
    local failedCritical = {}

    for _, moduleStatus in ipairs(statuses or {}) do
        if moduleStatus.critical == true and moduleStatus.status == 'failed' then
            failedCritical[#failedCritical + 1] = moduleStatus.name
        end
    end

    if #failedCritical > 0 then
        return fail('CRITICAL_MODULE_FAILED', 'At least one critical module is failed.', {
            failedCritical = failedCritical,
            statuses = statuses
        })
    end

    return pass('MODULES_OK', 'Module statuses are readable and no critical module is failed.', {
        count = #(statuses or {}),
        statuses = statuses
    })
end)

addTest('manual_runtime_boundaries', function()
    return skip('MANUAL_TESTS_REQUIRED', 'The remaining acceptance cases require controlled FXServer operations and are documented as manual tests.', {
        manual = {
            'resource stop/restart',
            'oxmysql missing or stopped',
            'database unavailable',
            'migration already applied and migration failure',
            'real player connect/drop',
            'server-to-client callback timeout/disconnect',
            'public mutating character exports'
        }
    })
end)

local function isAuthorized(source)
    if source == 0 then
        return true
    end

    return IsPlayerAceAllowed(source, COMMAND_ACE)
end

local function filterSuites(requested)
    if not requested or requested == '' or requested == 'all' then
        return suites
    end

    local selected = {}

    for _, suite in ipairs(suites) do
        if suite.name == requested then
            selected[#selected + 1] = suite
        end
    end

    return selected
end

local function runSuites(requested, invokedBy)
    local selected = filterSuites(requested)
    local summary = {
        pass = 0,
        fail = 0,
        skip = 0,
        total = #selected
    }

    if #selected == 0 then
        log('error', 'Unknown runtime test suite.', {
            requested = requested
        })
        return summary
    end

    log('info', 'Starting nexa-core runtime validation.', {
        requested = requested or 'all',
        invokedBy = invokedBy,
        coreState = GetResourceState(CORE_RESOURCE)
    })

    for _, suite in ipairs(selected) do
        local startedAt = nowMs()
        local ok, suiteResult = pcall(suite.callback)

        if not ok then
            suiteResult = fail('SUITE_ERROR', 'Runtime test suite crashed.', {
                error = tostring(suiteResult)
            })
        end

        suiteResult.durationMs = nowMs() - startedAt
        suiteResult.suite = suite.name
        summary[suiteResult.status] = (summary[suiteResult.status] or 0) + 1
        log(suiteResult.status == 'fail' and 'error' or 'info', 'Runtime test result.', suiteResult)
    end

    log(summary.fail > 0 and 'error' or 'info', 'Finished nexa-core runtime validation.', summary)
    return summary
end

RegisterCommand(COMMAND_NAME, function(source, args)
    if not isAuthorized(source) then
        log('warn', 'Runtime test command denied.', {
            source = source,
            ace = COMMAND_ACE
        })
        return
    end

    local requested = args and args[1] or 'all'

    CreateThread(function()
        runSuites(requested, source == 0 and 'console' or ('source:' .. source))
    end)
end, false)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    log('info', 'nexa-core runtime test harness loaded. Run the command manually.', {
        command = COMMAND_NAME,
        ace = COMMAND_ACE,
        autoRun = false
    })
end)
