local visible = false
local snapshot = { accounts = {}, invoices = {}, transactions = {} }

local function call(name, payload)
    local waiter = promise.new()
    local request = exports.nexa_api:TriggerServerCallback(name, payload or {}, function(response) waiter:resolve(response) end, 5000)
    if type(request) == 'table' and request.ok == false then return request end
    return Citizen.Await(waiter)
end

local function send(messageType, payload) SendNUIMessage({ type = messageType, payload = payload or {} }) end

function refresh()
    local accounts = call('nexa:banking:cb:getAccounts', {})
    local invoices = call('nexa:banking:cb:getInvoices', {})
    snapshot.accounts = accounts and accounts.data and accounts.data.accounts or {}
    snapshot.invoices = invoices and invoices.data and invoices.data.invoices or {}
    send('banking:snapshot', snapshot)
    return snapshot
end

function open()
    visible = true
    SetNuiFocus(true, true)
    send('banking:init', { theme = GetResourceState('nexa_theme') == 'started' and exports.nexa_theme:getTheme() or {}, components = GetResourceState('nexa_ui_components') == 'started' and exports.nexa_ui_components:getComponents() or {} })
    refresh()
    send('banking:visibility', { visible = true })
end

function close()
    visible = false
    SetNuiFocus(false, false)
    send('banking:visibility', { visible = false })
end

exports('open', open)
exports('close', close)
exports('refresh', refresh)
RegisterCommand('nexa_banking', open, false)
