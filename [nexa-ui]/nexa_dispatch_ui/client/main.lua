local visible = false
local snapshot = { calls = {}, units = {} }
local function call(name, payload) local waiter = promise.new(); local request = exports.nexa_api:TriggerServerCallback(name, payload or {}, function(response) waiter:resolve(response) end, 5000); if type(request) == 'table' and request.ok == false then return request end; return Citizen.Await(waiter) end
local function send(type, payload) SendNUIMessage({ type = type, payload = payload or {} }) end
function refresh() local calls = call('nexa:dispatch:cb:listCalls', { limit = 100 }); snapshot.calls = calls and calls.data or {}; send('dispatch:snapshot', snapshot); return snapshot end
function open() visible = true; SetNuiFocus(true, true); send('dispatch:init', { theme = GetResourceState('nexa_theme') == 'started' and exports.nexa_theme:getTheme() or {} }); refresh(); send('dispatch:visibility', { visible = true }) end
function close() visible = false; SetNuiFocus(false, false); send('dispatch:visibility', { visible = false }) end
exports('open', open)
exports('close', close)
exports('refresh', refresh)
RegisterCommand('nexa_dispatch', open, false)
