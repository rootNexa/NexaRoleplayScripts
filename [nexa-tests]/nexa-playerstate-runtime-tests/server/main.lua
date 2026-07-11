local SUITES = {
    lifecycle = true,
    spawn = true,
    position = true,
    bucket = true,
    lifestate = true,
    identity_spawn = true,
    disconnect = true,
    restart = true,
    security = true,
    all = true
}

local function result(suite, status, message)
    return {
        suite = suite,
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

    if suite == 'lifecycle' then
        local actions = exports.nexa_playerstate:GetPlayerState(1)
        return result(suite, type(actions) == 'table' and 'passed' or 'open', 'Static export smoke check.')
    end

    if suite == 'identity_spawn' then
        local identityStarted = GetResourceState('nexa-identity') == 'started'
        local playerstateStarted = GetResourceState('nexa_playerstate') == 'started'
        local characterStarted = GetResourceState('nexa-character') == 'started'

        if identityStarted and playerstateStarted and characterStarted then
            return result(suite, 'open', 'Resources are started; requires live selected character fixture to execute RequestSpawn end-to-end.')
        end

        return result(suite, 'failed', 'nexa-identity, nexa-character and nexa_playerstate must be started.')
    end

    return result(suite, 'open', 'Requires live FXServer player and safe test character.')
end

RegisterCommand('nexa_test_playerstate_runtime', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.playerstate_runtime') then
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
