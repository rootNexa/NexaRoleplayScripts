local cachedAccounts = {}

local function awaitServerCallback(name, payload)
    local waiter = promise.new()
    local request = exports.nexa_api:TriggerServerCallback(name, payload or {}, function(response)
        waiter:resolve(response)
    end, 5000)

    if type(request) == 'table' and request.ok == false then
        return request
    end

    return Citizen.Await(waiter)
end

local function notify(response)
    if response == nil then
        return
    end

    exports.nexa_ui:notify({
        title = 'Banking',
        description = response.message or 'Vorgang abgeschlossen.',
        type = response.success and 'success' or 'error'
    })
end

local function loadAccounts()
    local response = awaitServerCallback('nexa:banking:cb:getAccounts', {})

    if response ~= nil and response.success and response.data ~= nil then
        cachedAccounts = response.data.accounts or {}
    end

    notify(response)
    return response
end

local function getAccountOptions()
    local options = {}

    for _, account in ipairs(cachedAccounts) do
        options[#options + 1] = {
            value = account.id,
            label = ('%s (%s %s)'):format(account.account_number, tostring(account.balance), account.currency)
        }
    end

    return options
end

local function openTransferDialog()
    if #cachedAccounts == 0 then
        loadAccounts()
    end

    local input = exports.nexa_ui:inputDialog('Ueberweisung', {
        { type = 'select', label = 'Von Konto', options = getAccountOptions(), required = true },
        { type = 'input', label = 'Ziel-Kontonummer', required = true },
        { type = 'number', label = 'Betrag', required = true, min = 1 },
        { type = 'input', label = 'Verwendungszweck', required = false }
    })

    if input == nil then
        return
    end

    local response = awaitServerCallback('nexa:banking:cb:requestTransfer', {
        fromAccountId = input[1],
        toAccountNumber = input[2],
        amount = input[3],
        reason = input[4]
    })

    notify(response)
end

local function openTransactionsDialog()
    if #cachedAccounts == 0 then
        loadAccounts()
    end

    local input = exports.nexa_ui:inputDialog('Transaktionen', {
        { type = 'select', label = 'Konto', options = getAccountOptions(), required = true }
    })

    if input == nil then
        return
    end

    local response = awaitServerCallback('nexa:banking:cb:getTransactions', {
        accountId = input[1],
        limit = NexaBankingConfig.defaultHistoryLimit
    })

    notify(response)
end

local function openInvoiceDialog()
    if #cachedAccounts == 0 then
        loadAccounts()
    end

    local input = exports.nexa_ui:inputDialog('Rechnung bezahlen', {
        { type = 'number', label = 'Rechnungs-ID', required = true, min = 1 },
        { type = 'select', label = 'Von Konto', options = getAccountOptions(), required = true }
    })

    if input == nil then
        return
    end

    local response = awaitServerCallback('nexa:banking:cb:payInvoice', {
        invoiceId = input[1],
        fromAccountId = input[2]
    })

    notify(response)
end

RegisterNetEvent(NEXA_BANKING_EVENTS.requestResult, notify)

RegisterNetEvent(NEXA_BANKING_EVENTS.requestOpenMenu, function()
    exports.nexa_ui:registerContext({
        id = NexaBankingClient.contextId,
        title = 'Banking',
        options = {
            {
                title = 'Konten laden',
                icon = 'building-columns',
                onSelect = loadAccounts
            },
            {
                title = 'Privates Girokonto erstellen',
                icon = 'circle-plus',
                onSelect = function()
                    local response = awaitServerCallback('nexa:banking:cb:createPrivateAccount', {
                        accountType = 'checking'
                    })

                    notify(response)
                end
            },
            {
                title = 'Ueberweisung',
                icon = 'arrow-right-left',
                onSelect = openTransferDialog
            },
            {
                title = 'Transaktionshistorie',
                icon = 'receipt-text',
                onSelect = openTransactionsDialog
            },
            {
                title = 'Rechnung bezahlen',
                icon = 'file-check',
                onSelect = openInvoiceDialog
            }
        }
    })

    exports.nexa_ui:showContext(NexaBankingClient.contextId)
end)
