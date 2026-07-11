local function ok(name, details)
    print(('[nexa-beta-runtime-tests] PASS %s %s'):format(name, details or ''))
    return true
end

local function fail(name, details)
    print(('[nexa-beta-runtime-tests] FAIL %s %s'):format(name, details or ''))
    return false
end

local function hasResource(resourceName)
    local state = GetResourceState(resourceName)
    return state == 'started' or state == 'starting'
end

local function runCreators()
    if not hasResource('nexa_beta') then
        return fail('creators', 'nexa_beta is not started')
    end

    local response = exports.nexa_beta:ListCreators()
    local data = response and response.data or {}
    local creators = data.creators or {}

    return #creators > 0 and ok('creators', ('count=%s'):format(#creators)) or fail('creators', 'no creators registered')
end

local function runHealth()
    local response = exports.nexa_beta:CollectHealth()
    local data = response and response.data or {}
    local resources = data.resources or {}

    return #resources > 0 and ok('health', ('resources=%s'):format(#resources)) or fail('health', 'no resources reported')
end

local function runRelease()
    local response = exports.nexa_beta:GetReleaseMetadata()
    local data = response and response.data or {}

    return data.release_key == 'gp18-alpha' and ok('release', data.version or '') or fail('release', 'invalid release metadata')
end

local function runUi()
    return hasResource('nexa_ui') and ok('ui', 'nexa_ui is available') or fail('ui', 'nexa_ui is not started')
end

local function runAdmin()
    return hasResource('nexa_admin_ui') and ok('admin', 'nexa_admin_ui is available') or fail('admin', 'nexa_admin_ui is not started')
end

local suites = {
    creators = runCreators,
    health = runHealth,
    release = runRelease,
    ui = runUi,
    admin = runAdmin
}

local function runSuite(suiteName)
    if suiteName == 'all' then
        local passed = true

        for name, runner in pairs(suites) do
            passed = runner() and passed
        end

        return passed
    end

    local runner = suites[suiteName]
    return runner and runner() or fail('suite', ('unknown suite %s'):format(tostring(suiteName)))
end

RegisterCommand(NEXA_BETA_TESTS.command, function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, NEXA_BETA_TESTS.acePermission) then
        print('[nexa-beta-runtime-tests] permission denied')
        return
    end

    local suiteName = args[1] or 'all'
    local passed = runSuite(suiteName)
    print(('[nexa-beta-runtime-tests] result=%s suite=%s'):format(passed and 'pass' or 'fail', suiteName))
end, true)
