local cachedAccounts = {}

local function notify(response)
    if response == nil then
        return
    end

    lib.notify({
        title = 'Banking',
        description = response.message or 'Vorgang abgeschlossen.',
        type = response.success and 'success' or 'error'
    })
end

local function loadAccounts()
    local response = lib.callback.await('nexa:banking:cb:getAccounts', false)

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

    local input = lib.inputDialog('Ueberweisung', {
        { type = 'select', label = 'Von Konto', options = getAccountOptions(), required = true },
        { type = 'input', label = 'Ziel-Kontonummer', required = true },
        { type = 'number', label = 'Betrag', required = true, min = 1 },
        { type = 'input', label = 'Verwendungszweck', required = false }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:banking:cb:requestTransfer', false, {
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

    local input = lib.inputDialog('Transaktionen', {
        { type = 'select', label = 'Konto', options = getAccountOptions(), required = true }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:banking:cb:getTransactions', false, {
        accountId = input[1],
        limit = NexaBankingConfig.defaultHistoryLimit
    })

    notify(response)
end

local function openInvoiceDialog()
    if #cachedAccounts == 0 then
        loadAccounts()
    end

    local input = lib.inputDialog('Rechnung bezahlen', {
        { type = 'number', label = 'Rechnungs-ID', required = true, min = 1 },
        { type = 'select', label = 'Von Konto', options = getAccountOptions(), required = true }
    })

    if input == nil then
        return
    end

    local response = lib.callback.await('nexa:banking:cb:payInvoice', false, {
        invoiceId = input[1],
        fromAccountId = input[2]
    })

    notify(response)
end

RegisterNetEvent(NEXA_BANKING_EVENTS.requestResult, notify)

RegisterNetEvent(NEXA_BANKING_EVENTS.requestOpenMenu, function()
    lib.registerContext({
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
                    local response = lib.callback.await('nexa:banking:cb:createPrivateAccount', false, {
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

    lib.showContext(NexaBankingClient.contextId)
end)
