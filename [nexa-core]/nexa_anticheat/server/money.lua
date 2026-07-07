local function moneyResponse(success, code, message, data, meta, auditId)
    return {
        success = success == true,
        code = code or 'INTERNAL_ERROR',
        message = message or 'Money-Protection-Pruefung konnte nicht abgeschlossen werden.',
        data = data,
        meta = meta,
        audit_id = auditId
    }
end

local function isMoneyProtectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.moneyProtectionFeatureFlag)
end

local function writeMoneyAudit(action, severity, metadata)
    local result = exports.nexa_audit:writeSecurity({
        action = action,
        eventType = 'security',
        severity = severity or 'warning',
        resourceName = NEXA_ANTICHEAT.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function logMoneyWarning(message, metadata)
    exports.nexa_logs:warn(NEXA_ANTICHEAT.resourceName, message, metadata or {})
end

local function normalizeLimit(limit)
    local configuredLimit = NexaAnticheatServer.moneyProtection.reportLimit
    local requestedLimit = tonumber(limit) or configuredLimit

    if requestedLimit < 1 then
        return configuredLimit
    end

    return math.min(math.floor(requestedLimit), configuredLimit)
end

local function sortedEnabledKeys(values)
    local keys = {}

    for key, enabled in pairs(values or {}) do
        if enabled == true then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys)

    return keys
end

local function buildSqlInClause(values)
    local placeholders = {}

    for index = 1, #values do
        placeholders[index] = '?'
    end

    return table.concat(placeholders, ', ')
end

local function appendValues(target, values)
    for _, value in ipairs(values) do
        target[#target + 1] = value
    end
end

local function hasFindings(report)
    return #report.accountBalanceFindings > 0
        or #report.ledgerFindings > 0
        or #report.duplicatePayoutFindings > 0
        or #report.payoutCooldownFindings > 0
        or #report.unauthorizedMutationFindings > 0
end

local function buildReport(limit)
    local reportLimit = normalizeLimit(limit)
    local moneyConfig = NexaAnticheatServer.moneyProtection

    local accountBalanceFindings = MySQL.query.await([[
        SELECT id, account_number, balance, currency, updated_at
        FROM accounts
        WHERE balance < 0 OR balance > ?
        ORDER BY updated_at DESC, id DESC
        LIMIT ?
    ]], {
        moneyConfig.maxAccountBalance,
        reportLimit
    }) or {}

    local ledgerFindings = MySQL.query.await([[
        SELECT id, transaction_id, from_account_id, to_account_id, amount, category, resource_name, created_at
        FROM economy_ledger
        WHERE amount <= 0 OR amount > ? OR (from_account_id IS NULL AND to_account_id IS NULL)
        ORDER BY created_at DESC, id DESC
        LIMIT ?
    ]], {
        moneyConfig.maxTransactionAmount,
        reportLimit
    }) or {}

    local duplicatePayoutFindings = MySQL.query.await([[
        SELECT transaction_id, category, resource_name, COUNT(*) AS duplicate_count, MIN(created_at) AS first_seen_at, MAX(created_at) AS last_seen_at
        FROM economy_ledger
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? SECOND)
        GROUP BY transaction_id, category, resource_name
        HAVING COUNT(*) > 1
        ORDER BY last_seen_at DESC
        LIMIT ?
    ]], {
        moneyConfig.duplicateWindowSeconds,
        reportLimit
    }) or {}

    local payoutCategories = sortedEnabledKeys(moneyConfig.payoutCategories)
    local payoutCooldownFindings = {}

    if #payoutCategories > 0 then
        local payoutParams = {}
        appendValues(payoutParams, payoutCategories)
        payoutParams[#payoutParams + 1] = moneyConfig.payoutCooldownSeconds
        payoutParams[#payoutParams + 1] = reportLimit

        payoutCooldownFindings = MySQL.query.await(([[
        SELECT actor_character_id, category, COUNT(*) AS payout_count, MIN(created_at) AS first_seen_at, MAX(created_at) AS last_seen_at
        FROM economy_ledger
        WHERE actor_character_id IS NOT NULL
            AND category IN (%s)
            AND created_at >= DATE_SUB(NOW(), INTERVAL ? SECOND)
        GROUP BY actor_character_id, category
        HAVING COUNT(*) > 1
        ORDER BY last_seen_at DESC
        LIMIT ?
    ]]):format(buildSqlInClause(payoutCategories)), payoutParams) or {}
    end

    local authorizedLedgerResources = sortedEnabledKeys(moneyConfig.authorizedLedgerResources)
    local unauthorizedMutationFindings = {}

    if #authorizedLedgerResources > 0 then
        local resourceParams = {}
        appendValues(resourceParams, authorizedLedgerResources)
        resourceParams[#resourceParams + 1] = reportLimit

        unauthorizedMutationFindings = MySQL.query.await(([[
        SELECT id, transaction_id, amount, category, resource_name, created_at
        FROM economy_ledger
        WHERE resource_name NOT IN (%s)
        ORDER BY created_at DESC, id DESC
        LIMIT ?
    ]]):format(buildSqlInClause(authorizedLedgerResources)), resourceParams) or {}
    end

    return {
        accountBalanceFindings = accountBalanceFindings,
        ledgerFindings = ledgerFindings,
        duplicatePayoutFindings = duplicatePayoutFindings,
        payoutCooldownFindings = payoutCooldownFindings,
        unauthorizedMutationFindings = unauthorizedMutationFindings
    }
end

function validateMoneyIntegrity(payload)
    if not isMoneyProtectionEnabled() then
        return moneyResponse(false, 'FEATURE_DISABLED', 'Money Protection ist deaktiviert.', nil, nil, nil)
    end

    local reportOk, report = pcall(buildReport, payload and payload.limit)

    if not reportOk then
        local auditId = writeMoneyAudit('money.integrity.database_error', 'error', {
            error = tostring(report)
        })

        logMoneyWarning('Money Protection konnte die Integrity-Pruefung nicht ausfuehren.', {
            auditId = auditId
        })

        return moneyResponse(false, 'DATABASE_ERROR', 'Money-Integrity-Pruefung konnte nicht ausgefuehrt werden.', nil, nil, auditId)
    end

    local suspicious = hasFindings(report)
    local auditId = writeMoneyAudit(suspicious and 'money.integrity.suspicious' or 'money.integrity.validated', suspicious and 'warning' or 'info', {
        suspicious = suspicious,
        accountBalanceFindings = #report.accountBalanceFindings,
        ledgerFindings = #report.ledgerFindings,
        duplicatePayoutFindings = #report.duplicatePayoutFindings,
        payoutCooldownFindings = #report.payoutCooldownFindings,
        unauthorizedMutationFindings = #report.unauthorizedMutationFindings
    })

    if suspicious then
        logMoneyWarning('Money Protection hat verdaechtige Geldbewegungen markiert.', {
            auditId = auditId
        })
    end

    return moneyResponse(true, suspicious and 'SUSPICIOUS_MONEY_ACTIVITY' or 'OK', 'Money-Integrity-Pruefung wurde abgeschlossen.', report, {
        suspicious = suspicious
    }, auditId)
end

function validateAccountBalance(payload)
    if not isMoneyProtectionEnabled() then
        return moneyResponse(false, 'FEATURE_DISABLED', 'Money Protection ist deaktiviert.', nil, nil, nil)
    end

    local accountId = tonumber(payload and payload.accountId)

    if accountId == nil or accountId <= 0 then
        return moneyResponse(false, 'INVALID_INPUT', 'Ungueltige Konto-ID.', nil, nil, nil)
    end

    local queryOk, account = pcall(MySQL.single.await, [[
        SELECT id, account_number, balance, currency, updated_at
        FROM accounts
        WHERE id = ?
        LIMIT 1
    ]], {
        math.floor(accountId)
    })

    if not queryOk then
        local auditId = writeMoneyAudit('money.account_balance.database_error', 'error', {
            accountId = math.floor(accountId),
            error = tostring(account)
        })

        logMoneyWarning('Money Protection konnte den Kontostand nicht pruefen.', {
            accountId = math.floor(accountId),
            auditId = auditId
        })

        return moneyResponse(false, 'DATABASE_ERROR', 'Kontostand konnte nicht geprueft werden.', nil, nil, auditId)
    end

    if account == nil then
        return moneyResponse(false, 'NOT_FOUND', 'Konto wurde nicht gefunden.', nil, nil, nil)
    end

    local balance = tonumber(account.balance)
    local valid = balance ~= nil and balance >= 0 and balance <= NexaAnticheatServer.moneyProtection.maxAccountBalance
    local auditId = nil

    if not valid then
        auditId = writeMoneyAudit('money.account_balance.suspicious', 'warning', {
            accountId = account.id,
            balance = account.balance
        })
        logMoneyWarning('Money Protection hat einen ungueltigen Kontostand markiert.', {
            accountId = account.id,
            balance = account.balance
        })
    end

    return moneyResponse(true, valid and 'OK' or 'SUSPICIOUS_ACCOUNT_BALANCE', 'Kontostand wurde geprueft.', {
        account = account,
        valid = valid
    }, nil, auditId)
end

function validateEconomyLedger(payload)
    if not isMoneyProtectionEnabled() then
        return moneyResponse(false, 'FEATURE_DISABLED', 'Money Protection ist deaktiviert.', nil, nil, nil)
    end

    local transactionId = payload and payload.transactionId

    if type(transactionId) ~= 'string' or transactionId == '' or #transactionId > 64 then
        return moneyResponse(false, 'INVALID_INPUT', 'Ungueltige Transaktions-ID.', nil, nil, nil)
    end

    local queryOk, rows = pcall(MySQL.query.await, [[
        SELECT id, transaction_id, from_account_id, to_account_id, amount, reason, category, resource_name, created_at
        FROM economy_ledger
        WHERE transaction_id = ?
        ORDER BY id ASC
    ]], {
        transactionId
    })

    if not queryOk then
        local auditId = writeMoneyAudit('money.ledger.database_error', 'error', {
            transactionId = transactionId,
            error = tostring(rows)
        })

        logMoneyWarning('Money Protection konnte den Ledger-Eintrag nicht pruefen.', {
            transactionId = transactionId,
            auditId = auditId
        })

        return moneyResponse(false, 'DATABASE_ERROR', 'Ledger-Eintrag konnte nicht geprueft werden.', nil, nil, auditId)
    end

    rows = rows or {}

    if #rows == 0 then
        return moneyResponse(false, 'NOT_FOUND', 'Ledger-Eintrag wurde nicht gefunden.', nil, nil, nil)
    end

    local suspicious = #rows > 1

    for _, row in ipairs(rows) do
        local amount = tonumber(row.amount)

        if amount == nil or amount <= 0 or amount > NexaAnticheatServer.moneyProtection.maxTransactionAmount then
            suspicious = true
        end

        if row.from_account_id == nil and row.to_account_id == nil then
            suspicious = true
        end
    end

    local auditId = nil

    if suspicious then
        auditId = writeMoneyAudit('money.ledger.suspicious', 'warning', {
            transactionId = transactionId,
            entries = #rows
        })
        logMoneyWarning('Money Protection hat einen verdaechtigen Ledger-Eintrag markiert.', {
            transactionId = transactionId
        })
    end

    return moneyResponse(true, suspicious and 'SUSPICIOUS_LEDGER_ENTRY' or 'OK', 'Ledger-Eintrag wurde geprueft.', {
        entries = rows,
        suspicious = suspicious
    }, nil, auditId)
end

function getMoneyReconciliationReport(payload)
    if not isMoneyProtectionEnabled() then
        return moneyResponse(false, 'FEATURE_DISABLED', 'Money Protection ist deaktiviert.', nil, nil, nil)
    end

    local reportOk, report = pcall(buildReport, payload and payload.limit)

    if not reportOk then
        local auditId = writeMoneyAudit('money.reconciliation.database_error', 'error', {
            error = tostring(report)
        })

        logMoneyWarning('Money Protection konnte den Reconciliation-Report nicht erstellen.', {
            auditId = auditId
        })

        return moneyResponse(false, 'DATABASE_ERROR', 'Money-Reconciliation-Report konnte nicht erstellt werden.', nil, nil, auditId)
    end

    local auditId = writeMoneyAudit('money.reconciliation.report', hasFindings(report) and 'warning' or 'info', {
        suspicious = hasFindings(report)
    })

    return moneyResponse(true, 'OK', 'Money-Reconciliation-Report wurde erstellt.', report, {
        suspicious = hasFindings(report)
    }, auditId)
end

exports('validateMoneyIntegrity', validateMoneyIntegrity)
exports('validateAccountBalance', validateAccountBalance)
exports('validateEconomyLedger', validateEconomyLedger)
exports('getMoneyReconciliationReport', getMoneyReconciliationReport)
