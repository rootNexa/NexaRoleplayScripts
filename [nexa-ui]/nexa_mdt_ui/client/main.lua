local visible = false
local snapshot = {}
local function call(name, payload) local waiter = promise.new(); local request = exports.nexa_api:TriggerServerCallback(name, payload or {}, function(response) waiter:resolve(response) end, 5000); if type(request) == 'table' and request.ok == false then return request end; return Citizen.Await(waiter) end
local function send(type, payload) SendNUIMessage({ type = type, payload = payload or {} }) end
function refresh() local response = call('nexa:mdt:cb:getSnapshot', { mdtType = 'police' }); snapshot = response and response.data or {}; send('mdt:snapshot', snapshot); return snapshot end
function open() visible = true; SetNuiFocus(true, true); send('mdt:init', { theme = GetResourceState('nexa_theme') == 'started' and exports.nexa_theme:getTheme() or {} }); refresh(); send('mdt:visibility', { visible = true }) end
function close() visible = false; SetNuiFocus(false, false); send('mdt:visibility', { visible = false }) end
exports('open', open)
exports('close', close)
exports('refresh', refresh)
RegisterCommand('nexa_mdt_ui', open, false)
