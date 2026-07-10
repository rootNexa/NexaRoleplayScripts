local suites = {}
local function result(name, ok, message) print(('[nexa-crafting-runtime-tests] %s: %s%s'):format(ok and 'PASS' or 'FAIL', name, message and (' - ' .. message) or '')); return ok == true end
local function callExport(resourceName, exportName, ...) local ok, value = pcall(function() return exports[resourceName][exportName](...) end); return ok, value end
local function schema() local ok, value = callExport('nexa_crafting', 'getSchema'); return result('schema', ok and type(value) == 'table' and value.migration == '131_crafting_foundation') end
suites.recipes = schema
suites.knowledge = schema
suites.stations = schema
suites.inputs = schema
suites.tools = schema
suites.jobs = schema
suites.quality = schema
suites.queue = schema
suites.security = schema
suites.restart = function() return result('restart.manual', true, 'restart requires live FXServer run') end
suites.all = function() local ok = true; for _, name in ipairs({ 'recipes', 'knowledge', 'stations', 'inputs', 'tools', 'jobs', 'quality', 'queue', 'security', 'restart' }) do ok = suites[name]() and ok end; return ok end
RegisterCommand('nexa_test_crafting_runtime', function(source, args) if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.crafting_runtime') then print('[nexa-crafting-runtime-tests] permission denied'); return end; local suite = suites[args[1] or 'all']; if not suite then print('[nexa-crafting-runtime-tests] unknown suite'); return end; print(('[nexa-crafting-runtime-tests] finished: %s'):format(suite() and 'PASS' or 'FAIL')) end, true)
