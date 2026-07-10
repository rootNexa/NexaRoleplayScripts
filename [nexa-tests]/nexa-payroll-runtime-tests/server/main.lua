local SUITES = { policies = true, dutytime = true, periods = true, calculation = true, runs = true, economy = true, government = true, security = true, restart = true, all = true }
local function result(suite, status, message, data) return { suite = suite, status = status, message = message, data = data } end
local function runSuite(suite)
    if suite == 'all' then local r = {}; for n in pairs(SUITES) do if n ~= 'all' then r[#r+1] = runSuite(n) end end; table.sort(r, function(a,b) return a.suite < b.suite end); return r end
    if suite == 'policies' then local ok, status = pcall(function() return exports.nexa_payroll:getStatus() end); return result(suite, ok and 'passed' or 'failed', 'Payroll status smoke check.', status) end
    if suite == 'periods' then local ok, schema = pcall(function() return exports.nexa_payroll:getSchema() end); return result(suite, ok and 'passed' or 'failed', 'Payroll schema smoke check.', schema) end
    return result(suite, 'open', 'Requires isolated FXServer fixtures, organizations, characters and accounts.')
end
RegisterCommand('nexa_test_payroll_runtime', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.payroll_runtime') then print(json.encode(result('auth', 'failed', 'ACE permission missing.'))); return end
    local suite = args[1] or 'all'; if not SUITES[suite] then print(json.encode(result(suite, 'failed', 'Unknown suite.'))); return end
    print(json.encode(runSuite(suite)))
end, true)
