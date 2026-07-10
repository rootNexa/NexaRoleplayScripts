local SUITES = {
    warnings = true,
    bans = true,
    kick = true,
    teleport = true,
    freeze = true,
    recovery = true,
    spectate = true,
    noclip = true,
    notes = true,
    security = true,
    restart = true,
    all = true
}

local function result(name, status, message)
    return {
        suite = name,
        status = status,
        message = message
    }
end

local function runSuite(suite)
    if suite == 'all' then
        local results = {}

        for name in pairs(SUITES) do
            if name ~= 'all' then
                results[#results + 1] = runSuite(name)
            end
        end

        return results
    end

    if suite == 'warnings' then
        local actions = exports.nexa_admin:ListActions()
        return result(suite, actions.success and 'passed' or 'failed', 'Action catalog reachable.')
    end

    return result(suite, 'open', 'Requires live FXServer players and safe test accounts.')
end

RegisterCommand('nexa_test_admin_runtime', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.admin_runtime') then
        print(json.encode(result('auth', 'failed', 'ACE permission missing.')))
        return
    end

    local suite = args[1] or 'all'

    if not SUITES[suite] then
        print(json.encode(result(suite, 'failed', 'Unknown suite.')))
        return
    end

    print(json.encode(runSuite(suite)))
end, true)
