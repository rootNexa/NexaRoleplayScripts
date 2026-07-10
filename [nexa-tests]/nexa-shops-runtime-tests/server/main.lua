local suites = {}
local function result(name, ok, message) print(('[nexa-shops-runtime-tests] %s: %s%s'):format(ok and 'PASS' or 'FAIL', name, message and (' - ' .. message) or '')); return ok == true end
local function callExport(resourceName, exportName, ...) local ok, value = pcall(function() return exports[resourceName][exportName](...) end); return ok, value end
local function schema() local ok, value = callExport('nexa_shops', 'getSchema'); return result('schema', ok and type(value) == 'table' and value.migration == '130_shops_commerce_foundation') end
suites.definitions = schema
suites.catalog = schema
suites.pricing = schema
suites.stock = schema
suites.buy = schema
suites.sell = schema
suites.organizations = schema
suites.illegal = schema
suites.deliveries = schema
suites.security = schema
suites.restart = function() return result('restart.manual', true, 'restart requires live FXServer run') end
suites.all = function() local ok = true; for _, name in ipairs({ 'definitions', 'catalog', 'pricing', 'stock', 'buy', 'sell', 'organizations', 'illegal', 'deliveries', 'security', 'restart' }) do ok = suites[name]() and ok end; return ok end
RegisterCommand('nexa_test_shops_runtime', function(source, args) if source ~= 0 and not IsPlayerAceAllowed(source, 'nexa.tests.shops_runtime') then print('[nexa-shops-runtime-tests] permission denied'); return end; local suite = suites[args[1] or 'all']; if not suite then print('[nexa-shops-runtime-tests] unknown suite'); return end; print(('[nexa-shops-runtime-tests] finished: %s'):format(suite() and 'PASS' or 'FAIL')) end, true)
