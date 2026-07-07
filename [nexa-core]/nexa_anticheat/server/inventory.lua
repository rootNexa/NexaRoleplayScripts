local function inventoryResponse(success, code, message, data, meta, auditId)
    return {
        success = success == true,
        code = code or 'INTERNAL_ERROR',
        message = message or 'Inventory-Protection-Pruefung konnte nicht abgeschlossen werden.',
        data = data,
        meta = meta,
        audit_id = auditId
    }
end

local function isInventoryProtectionEnabled()
    return exports.nexa_featureflags:isEnabled(NexaAnticheatConfig.inventoryProtectionFeatureFlag)
end

local function writeInventoryAudit(action, severity, metadata)
    local result = exports.nexa_audit:writeSecurity({
        action = action,
        eventType = 'security',
        severity = severity or 'warning',
        resourceName = NEXA_ANTICHEAT.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function logInventoryWarning(message, metadata)
    exports.nexa_logs:warn(NEXA_ANTICHEAT.resourceName, message, metadata or {})
end

local function normalizeLimit(limit)
    local configuredLimit = NexaAnticheatServer.inventoryProtection.reportLimit
    local requestedLimit = tonumber(limit) or configuredLimit

    if requestedLimit < 1 then
        return configuredLimit
    end

    return math.min(math.floor(requestedLimit), configuredLimit)
end

local function normalizeItemName(value)
    if type(value) ~= 'string' then
        return nil
    end

    local itemName = value:gsub('^%s+', ''):gsub('%s+$', '')

    if itemName == '' or #itemName > 64 or itemName:match('^[%w_]+$') == nil then
        return nil
    end

    return itemName
end

local function normalizeStashName(value)
    if type(value) ~= 'string' then
        return nil
    end

    local stashName = value:gsub('^%s+', ''):gsub('%s+$', '')

    if stashName == '' or #stashName > 64 or stashName:match('^[%w_:%-]+$') == nil then
        return nil
    end

    return stashName
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
    return #report.ledgerFindings > 0
        or #report.duplicateItemFindings > 0
        or #report.suspiciousMovementFindings > 0
        or #report.unauthorizedMutationFindings > 0
        or #report.impossibleStashAccessFindings > 0
        or #report.highRiskItemFindings > 0
end

local function queryMetadataStashKey(key)
    return ("JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.%s'))"):format(key)
end

local function buildImpossibleStashQuery(stashKeys)
    local selects = {}

    for _, key in ipairs(stashKeys) do
        selects[#selects + 1] = ([[SELECT id, event_id, character_id, player_id, item_name, amount, action, resource_name, '%s' AS stash_key, %s AS stash_name, created_at FROM item_ledger WHERE metadata IS NOT NULL AND %s IS NOT NULL]]):format(key, queryMetadataStashKey(key), queryMetadataStashKey(key))
    end

    return ([[
        SELECT ledger.id, ledger.event_id, ledger.character_id, ledger.player_id, ledger.item_name, ledger.amount, ledger.action, ledger.resource_name, ledger.stash_key, ledger.stash_name, ledger.created_at
        FROM (
            %s
        ) ledger
        LEFT JOIN stash_registry sr ON sr.stash_name = ledger.stash_name AND sr.is_active = TRUE
        WHERE (ledger.stash_key = 'stashName' OR ledger.stash_name LIKE 'stash:%%')
            AND sr.id IS NULL
        ORDER BY ledger.created_at DESC, ledger.id DESC
        LIMIT ?
    ]]):format(table.concat(selects, ' UNION ALL '))
end

local function buildReport(limit)
    local reportLimit = normalizeLimit(limit)
    local inventoryConfig = NexaAnticheatServer.inventoryProtection

    local ledgerFindings = MySQL.query.await([[
        SELECT id, event_id, character_id, player_id, item_name, amount, action, resource_name, created_at
        FROM item_ledger
        WHERE amount <= 0
            OR amount > ?
            OR item_name NOT REGEXP '^[A-Za-z0-9_]+$'
            OR CHAR_LENGTH(item_name) > 64
            OR event_id IS NULL
            OR event_id = ''
        ORDER BY created_at DESC, id DESC
        LIMIT ?
    ]], {
        inventoryConfig.maxItemAmount,
        reportLimit
    }) or {}

    local duplicateItemFindings = MySQL.query.await([[
        SELECT event_id, item_name, action, resource_name, COUNT(*) AS duplicate_count, MIN(created_at) AS first_seen_at, MAX(created_at) AS last_seen_at
        FROM item_ledger
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? SECOND)
        GROUP BY event_id, item_name, action, resource_name
        HAVING COUNT(*) > 1
        ORDER BY last_seen_at DESC
        LIMIT ?
    ]], {
        inventoryConfig.duplicateWindowSeconds,
        reportLimit
    }) or {}

    local movementActions = sortedEnabledKeys(inventoryConfig.movementActions)
    local suspiciousMovementFindings = {}

    if #movementActions > 0 then
        local movementParams = {}
        movementParams[#movementParams + 1] = inventoryConfig.movementWindowSeconds
        appendValues(movementParams, movementActions)
        movementParams[#movementParams + 1] = inventoryConfig.maxMovementsPerWindow
        movementParams[#movementParams + 1] = reportLimit

        suspiciousMovementFindings = MySQL.query.await(([[
            SELECT player_id, character_id, item_name, action, COUNT(*) AS movement_count, SUM(amount) AS total_amount, MIN(created_at) AS first_seen_at, MAX(created_at) AS last_seen_at
            FROM item_ledger
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? SECOND)
                AND action IN (%s)
            GROUP BY player_id, character_id, item_name, action
            HAVING COUNT(*) > ?
            ORDER BY movement_count DESC, last_seen_at DESC
            LIMIT ?
        ]]):format(buildSqlInClause(movementActions)), movementParams) or {}
    end

    local authorizedResources = sortedEnabledKeys(inventoryConfig.authorizedItemResources)
    local unauthorizedMutationFindings = {}

    if #authorizedResources > 0 then
        local resourceParams = {}
        appendValues(resourceParams, authorizedResources)
        resourceParams[#resourceParams + 1] = reportLimit

        unauthorizedMutationFindings = MySQL.query.await(([[
            SELECT id, event_id, character_id, player_id, item_name, amount, action, resource_name, created_at
            FROM item_ledger
            WHERE resource_name NOT IN (%s)
            ORDER BY created_at DESC, id DESC
            LIMIT ?
        ]]):format(buildSqlInClause(authorizedResources)), resourceParams) or {}
    end

    local stashKeys = sortedEnabledKeys(inventoryConfig.stashMetadataKeys)
    local impossibleStashAccessFindings = {}

    if #stashKeys > 0 then
        impossibleStashAccessFindings = MySQL.query.await(buildImpossibleStashQuery(stashKeys), {
            reportLimit
        }) or {}
    end

    local highRiskItems = sortedEnabledKeys(inventoryConfig.highRiskItems)
    local highRiskItemFindings = {}

    if #highRiskItems > 0 then
        local highRiskParams = {}
        appendValues(highRiskParams, highRiskItems)
        highRiskParams[#highRiskParams + 1] = reportLimit

        highRiskItemFindings = MySQL.query.await(([[
            SELECT id, event_id, character_id, player_id, item_name, amount, action, resource_name, created_at
            FROM item_ledger
            WHERE item_name IN (%s)
            ORDER BY created_at DESC, id DESC
            LIMIT ?
        ]]):format(buildSqlInClause(highRiskItems)), highRiskParams) or {}
    end

    return {
        ledgerFindings = ledgerFindings,
        duplicateItemFindings = duplicateItemFindings,
        suspiciousMovementFindings = suspiciousMovementFindings,
        unauthorizedMutationFindings = unauthorizedMutationFindings,
        impossibleStashAccessFindings = impossibleStashAccessFindings,
        highRiskItemFindings = highRiskItemFindings
    }
end

function validateInventoryIntegrity(payload)
    if not isInventoryProtectionEnabled() then
        return inventoryResponse(false, 'FEATURE_DISABLED', 'Inventory Protection ist deaktiviert.', nil, nil, nil)
    end

    local reportOk, report = pcall(buildReport, payload and payload.limit)

    if not reportOk then
        local auditId = writeInventoryAudit('inventory.integrity.database_error', 'error', {
            error = tostring(report)
        })

        logInventoryWarning('Inventory Protection konnte die Integrity-Pruefung nicht ausfuehren.', {
            auditId = auditId
        })

        return inventoryResponse(false, 'DATABASE_ERROR', 'Inventory-Integrity-Pruefung konnte nicht ausgefuehrt werden.', nil, nil, auditId)
    end

    local suspicious = hasFindings(report)
    local auditId = writeInventoryAudit(suspicious and 'inventory.integrity.suspicious' or 'inventory.integrity.validated', suspicious and 'warning' or 'info', {
        suspicious = suspicious,
        ledgerFindings = #report.ledgerFindings,
        duplicateItemFindings = #report.duplicateItemFindings,
        suspiciousMovementFindings = #report.suspiciousMovementFindings,
        unauthorizedMutationFindings = #report.unauthorizedMutationFindings,
        impossibleStashAccessFindings = #report.impossibleStashAccessFindings,
        highRiskItemFindings = #report.highRiskItemFindings
    })

    if suspicious then
        logInventoryWarning('Inventory Protection hat verdaechtige Itemmuster markiert.', {
            auditId = auditId
        })
    end

    return inventoryResponse(true, suspicious and 'SUSPICIOUS_INVENTORY_ACTIVITY' or 'OK', 'Inventory-Integrity-Pruefung wurde abgeschlossen.', report, {
        suspicious = suspicious
    }, auditId)
end

function validateOxInventoryAccess(payload)
    if not isInventoryProtectionEnabled() then
        return inventoryResponse(false, 'FEATURE_DISABLED', 'Inventory Protection ist deaktiviert.', nil, nil, nil)
    end

    if payload ~= nil and type(payload) ~= 'table' then
        return inventoryResponse(false, 'INVALID_INPUT', 'Ungueltiger Inventory-Zugriffskontext.', nil, nil, nil)
    end

    if GetResourceState('ox_inventory') ~= 'started' then
        local auditId = writeInventoryAudit('inventory.ox_access.unavailable', 'warning', {
            resource = 'ox_inventory'
        })

        return inventoryResponse(false, 'RESOURCE_UNAVAILABLE', 'ox_inventory ist nicht verfuegbar.', nil, nil, auditId)
    end

    local source = tonumber(payload and payload.source)

    if payload ~= nil and payload.source ~= nil and (source == nil or source < 1 or math.floor(source) ~= source) then
        local auditId = writeInventoryAudit('inventory.ox_access.invalid_input', 'warning', {
            field = 'source',
            valueType = type(payload.source)
        })

        logInventoryWarning('Inventory Protection hat ungueltige Zugriffsdaten markiert.', {
            field = 'source',
            auditId = auditId
        })

        return inventoryResponse(false, 'INVALID_INPUT', 'Ungueltige Spielerquelle fuer Inventory-Zugriff.', nil, nil, auditId)
    end

    if source ~= nil then
        local sessionValid, sessionCode = NexaAnticheatValidateSession(math.floor(source))

        if not sessionValid then
            local auditId = writeInventoryAudit('inventory.ox_access.suspicious', 'warning', {
                source = math.floor(source),
                code = sessionCode
            })

            logInventoryWarning('Inventory Protection hat einen ungueltigen Inventory-Zugriff markiert.', {
                source = math.floor(source),
                code = sessionCode,
                auditId = auditId
            })

            return inventoryResponse(false, sessionCode, 'Inventory-Zugriff wurde abgelehnt.', nil, nil, auditId)
        end
    end

    local stashName = normalizeStashName(payload and payload.stashName)

    if payload ~= nil and payload.stashName ~= nil and stashName == nil then
        local auditId = writeInventoryAudit('inventory.stash_access.invalid_input', 'warning', {
            field = 'stashName',
            valueType = type(payload.stashName)
        })

        logInventoryWarning('Inventory Protection hat ungueltige Stash-Zugriffsdaten markiert.', {
            field = 'stashName',
            auditId = auditId
        })

        return inventoryResponse(false, 'INVALID_INPUT', 'Ungueltiger Stash-Name fuer Inventory-Zugriff.', nil, nil, auditId)
    end

    if stashName ~= nil then
        local queryOk, stash = pcall(MySQL.single.await, [[
            SELECT id, stash_name, owner_type, owner_id, is_active
            FROM stash_registry
            WHERE stash_name = ?
            LIMIT 1
        ]], {
            stashName
        })

        if not queryOk then
            local auditId = writeInventoryAudit('inventory.ox_access.database_error', 'error', {
                stashName = stashName,
                error = tostring(stash)
            })

            return inventoryResponse(false, 'DATABASE_ERROR', 'Stash-Zugriff konnte nicht geprueft werden.', nil, nil, auditId)
        end

        if stash == nil or stash.is_active == false or stash.is_active == 0 then
            local auditId = writeInventoryAudit('inventory.stash_access.suspicious', 'warning', {
                stashName = stashName,
                reason = stash == nil and 'STASH_NOT_REGISTERED' or 'STASH_INACTIVE'
            })

            logInventoryWarning('Inventory Protection hat unmoeglichen Stash-Zugriff markiert.', {
                stashName = stashName,
                auditId = auditId
            })

            return inventoryResponse(true, 'SUSPICIOUS_STASH_ACCESS', 'Stash-Zugriff wurde als verdaechtig markiert.', {
                stash = stash,
                suspicious = true
            }, {
                suspicious = true
            }, auditId)
        end
    end

    return inventoryResponse(true, 'OK', 'ox_inventory-Zugriff wurde geprueft.', {
        source = source and math.floor(source) or nil,
        stashName = stashName
    }, {
        suspicious = false
    }, nil)
end

function validateItemLedger(payload)
    if not isInventoryProtectionEnabled() then
        return inventoryResponse(false, 'FEATURE_DISABLED', 'Inventory Protection ist deaktiviert.', nil, nil, nil)
    end

    local eventId = payload and payload.eventId

    if type(eventId) ~= 'string' or eventId == '' or #eventId > 64 then
        return inventoryResponse(false, 'INVALID_INPUT', 'Ungueltige Item-Ledger-Event-ID.', nil, nil, nil)
    end

    local queryOk, rows = pcall(MySQL.query.await, [[
        SELECT id, event_id, character_id, player_id, item_name, amount, action, reason, resource_name, metadata, created_at
        FROM item_ledger
        WHERE event_id = ?
        ORDER BY id ASC
    ]], {
        eventId
    })

    if not queryOk then
        local auditId = writeInventoryAudit('inventory.ledger.database_error', 'error', {
            eventId = eventId,
            error = tostring(rows)
        })

        return inventoryResponse(false, 'DATABASE_ERROR', 'Item-Ledger-Eintrag konnte nicht geprueft werden.', nil, nil, auditId)
    end

    rows = rows or {}

    if #rows == 0 then
        return inventoryResponse(false, 'NOT_FOUND', 'Item-Ledger-Eintrag wurde nicht gefunden.', nil, nil, nil)
    end

    local suspicious = #rows > 1

    for _, row in ipairs(rows) do
        local amount = tonumber(row.amount)

        if normalizeItemName(row.item_name) == nil then
            suspicious = true
        end

        if amount == nil or amount <= 0 or amount > NexaAnticheatServer.inventoryProtection.maxItemAmount then
            suspicious = true
        end

        if type(row.resource_name) ~= 'string' or NexaAnticheatServer.inventoryProtection.authorizedItemResources[row.resource_name] ~= true then
            suspicious = true
        end
    end

    local auditId = nil

    if suspicious then
        auditId = writeInventoryAudit('inventory.ledger.suspicious', 'warning', {
            eventId = eventId,
            entries = #rows
        })

        logInventoryWarning('Inventory Protection hat einen verdaechtigen Item-Ledger-Eintrag markiert.', {
            eventId = eventId,
            auditId = auditId
        })
    end

    return inventoryResponse(true, suspicious and 'SUSPICIOUS_ITEM_LEDGER_ENTRY' or 'OK', 'Item-Ledger-Eintrag wurde geprueft.', {
        entries = rows,
        suspicious = suspicious
    }, nil, auditId)
end

function getInventoryReconciliationReport(payload)
    if not isInventoryProtectionEnabled() then
        return inventoryResponse(false, 'FEATURE_DISABLED', 'Inventory Protection ist deaktiviert.', nil, nil, nil)
    end

    local reportOk, report = pcall(buildReport, payload and payload.limit)

    if not reportOk then
        local auditId = writeInventoryAudit('inventory.reconciliation.database_error', 'error', {
            error = tostring(report)
        })

        logInventoryWarning('Inventory Protection konnte den Reconciliation-Report nicht erstellen.', {
            auditId = auditId
        })

        return inventoryResponse(false, 'DATABASE_ERROR', 'Inventory-Reconciliation-Report konnte nicht erstellt werden.', nil, nil, auditId)
    end

    local suspicious = hasFindings(report)
    local auditId = writeInventoryAudit('inventory.reconciliation.report', suspicious and 'warning' or 'info', {
        suspicious = suspicious
    })

    return inventoryResponse(true, 'OK', 'Inventory-Reconciliation-Report wurde erstellt.', report, {
        suspicious = suspicious
    }, auditId)
end

exports('validateInventoryIntegrity', validateInventoryIntegrity)
exports('validateOxInventoryAccess', validateOxInventoryAccess)
exports('validateItemLedger', validateItemLedger)
exports('getInventoryReconciliationReport', getInventoryReconciliationReport)
