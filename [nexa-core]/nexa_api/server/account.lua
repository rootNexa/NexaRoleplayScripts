local accountLimits = {
    minAmount = 1,
    maxAmount = 100000000,
    maxReasonLength = 128,
    maxHistoryLimit = 50,
    maxInvoiceLimit = 50,
    maxSignedBigInt = 9223372036854775807
}

local accountRolePermissions = {
    owner = {
        view = true,
        transfer = true,
        pay_invoice = true,
        manage_members = true
    },
    manager = {
        view = true,
        transfer = true,
        pay_invoice = true,
        manage_members = true
    },
    member = {
        view = true,
        transfer = true,
        pay_invoice = true
    },
    viewer = {
        view = true
    }
}

local function respond(success, code, message, data, meta, auditId)
    return NexaApiResponse(success, code, message, data, meta, auditId)
end

local function logApi(level, message, metadata)
    if GetResourceState('nexa_logs') ~= 'started' then
        return
    end

    exports.nexa_logs[level](NEXA_API.resourceName, message, metadata)
end

local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeAmount(value)
    local number = tonumber(value)

    if number == nil or number < accountLimits.minAmount or number > accountLimits.maxAmount then
        return nil
    end

    if math.floor(number) ~= number then
        return nil
    end

    return number
end

local function normalizeText(value, fallback)
    if value == nil then
        return fallback
    end

    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return fallback
    end

    return trimmed
end

local function encodeMetadata(metadata)
    if type(metadata) ~= 'table' then
        return json.encode({})
    end

    return json.encode(metadata)
end

local function buildTransactionId(prefix)
    return ('%s_%s_%04d'):format(prefix, os.date('%Y%m%d%H%M%S'), math.random(0, 9999))
end

local function buildInvoiceNumber(prefix)
    return ('%s%s%04d'):format(prefix, os.date('%y%m%d%H%M%S'), math.random(0, 9999))
end

local function getActor(source)
    local active = getActiveCharacter(source)

    if active == nil or not active.success or active.data == nil or active.data.character == nil then
        return nil, 'CHARACTER_NOT_LOADED'
    end

    return active.data.character, 'OK'
end

local function mapAccount(row)
    if row == nil then
        return nil
    end

    return {
        id = row.id,
        account_number = row.account_number,
        owner_type = row.owner_type,
        owner_id = row.owner_id,
        account_type = row.account_type,
        balance = row.balance,
        currency = row.currency,
        is_frozen = row.is_frozen == true or row.is_frozen == 1,
        role = row.role,
        created_at = row.created_at,
        updated_at = row.updated_at
    }
end

local function getAccountById(accountId)
    return mapAccount(MySQL.single.await([[
        SELECT id, account_number, owner_type, owner_id, account_type, balance, currency, is_frozen,
            created_at, updated_at
        FROM accounts
        WHERE id = ?
        LIMIT 1
    ]], {
        accountId
    }))
end

local function getAccountByNumber(accountNumber)
    return mapAccount(MySQL.single.await([[
        SELECT id, account_number, owner_type, owner_id, account_type, balance, currency, is_frozen,
            created_at, updated_at
        FROM accounts
        WHERE account_number = ?
        LIMIT 1
    ]], {
        accountNumber
    }))
end

local function getAccountReference(payload, idKey, numberKey)
    local accountId = normalizeId(payload[idKey])

    if accountId ~= nil then
        return getAccountById(accountId)
    end

    local accountNumber = normalizeText(payload[numberKey], nil)

    if accountNumber == nil or #accountNumber > 32 then
        return nil
    end

    return getAccountByNumber(accountNumber)
end

local function decodePermissions(value)
    if value == nil then
        return {}
    end

    if type(value) == 'table' then
        return value
    end

    if type(value) ~= 'string' or value == '' then
        return {}
    end

    local decoded = json.decode(value)

    if type(decoded) ~= 'table' then
        return {}
    end

    return decoded
end

local function permissionsContain(permissions, permission)
    if permissions[permission] == true then
        return true
    end

    for _, value in pairs(permissions) do
        if value == permission then
            return true
        end
    end

    return false
end

local function hasFactionAccountPermission(source, characterId, factionId, permission)
    local globalFactionPermission = ('faction.accounts.%s'):format(permission)

    if hasGlobalPermission(source, globalFactionPermission) then
        return true
    end

    if hasGlobalPermission(source, 'government.members.manage') then
        return true
    end

    local membership = MySQL.single.await([[ 
        SELECT fg.id AS grade_id, fg.permissions
        FROM faction_members fm
        JOIN factions f ON f.id = fm.faction_id
        JOIN faction_grades fg ON fg.id = fm.grade_id
        WHERE fm.character_id = ? AND fm.faction_id = ? AND fm.left_at IS NULL AND f.status = 'active'
        LIMIT 1
    ]], {
        characterId,
        factionId
    })

    if membership == nil then
        return false
    end

    if permissionsContain(decodePermissions(membership.permissions), globalFactionPermission) then
        return true
    end

    local explicit = MySQL.scalar.await([[ 
        SELECT id
        FROM faction_permissions
        WHERE faction_grade_id = ? AND permission = ? AND is_allowed = TRUE
        LIMIT 1
    ]], {
        membership.grade_id,
        globalFactionPermission
    })

    return explicit ~= nil
end

local function hasAccountPermission(source, characterId, account, permission)
    if account == nil or characterId == nil then
        return false
    end

    if account.owner_type == 'character' and tonumber(account.owner_id) == tonumber(characterId) then
        return true
    end

    if account.owner_type == 'faction' and tonumber(account.owner_id) ~= nil then
        return hasFactionAccountPermission(source, characterId, tonumber(account.owner_id), permission)
    end

    local member = MySQL.single.await([[
        SELECT role, permissions
        FROM account_members
        WHERE account_id = ? AND character_id = ? AND revoked_at IS NULL
            AND (expires_at IS NULL OR expires_at > NOW())
        LIMIT 1
    ]], {
        account.id,
        characterId
    })

    if member == nil then
        return false
    end

    local rolePermissions = accountRolePermissions[member.role] or {}

    if rolePermissions[permission] then
        return true
    end

    return permissionsContain(decodePermissions(member.permissions), permission)
end

local function writeAccountAudit(action, actor, targetAccountId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'account',
        severity = 'info',
        actorPlayerId = actor and actor.player_id or nil,
        actorCharacterId = actor and actor.id or nil,
        targetType = 'account',
        targetId = targetAccountId,
        action = action,
        resourceName = NEXA_API.resourceName,
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function hasGlobalPermission(source, permission)
    if GetResourceState('nexa_permissions') ~= 'started' then
        return false
    end

    local result = exports.nexa_permissions:has(source, permission)

    return result ~= nil and result.success == true
end

local function createAccountNumber()
    return ('NXA%s%04d'):format(os.date('%y%m%d%H%M%S'), math.random(0, 9999))
end

local function generateAccountNumber()
    for _ = 1, 10 do
        local accountNumber = createAccountNumber()
        local existing = MySQL.scalar.await('SELECT id FROM accounts WHERE account_number = ? LIMIT 1', {
            accountNumber
        })

        if existing == nil then
            return accountNumber
        end
    end

    return nil
end

local function getPrimaryOwnerAccount(ownerType, ownerId)
    local preferredType = {
        character = 'checking',
        business = 'business',
        faction = 'faction',
        system = 'system'
    }

    if preferredType[ownerType] == nil then
        return nil
    end

    return mapAccount(MySQL.single.await([[
        SELECT id, account_number, owner_type, owner_id, account_type, balance, currency, is_frozen,
            created_at, updated_at
        FROM accounts
        WHERE owner_type = ? AND owner_id = ? AND account_type = ?
        ORDER BY created_at ASC
        LIMIT 1
    ]], {
        ownerType,
        ownerId,
        preferredType[ownerType]
    }))
end

local function getInvokingResourceName()
    return GetInvokingResource() or NEXA_API.resourceName
end

local function isEmsBillingAllowed(source)
    if type(hasFactionPermission) ~= 'function' then
        return false
    end

    local permission = hasFactionPermission(source, {
        factionName = 'ems',
        permission = 'ems.billing.create'
    })

    if type(permission) ~= 'table' or permission.success ~= true then
        return false
    end

    if type(getCurrentFaction) ~= 'function' then
        return false
    end

    local current = getCurrentFaction(source, {
        factionName = 'ems'
    })

    return type(current) == 'table'
        and current.success == true
        and current.data ~= nil
        and current.data.membership ~= nil
        and current.data.dutySession ~= nil
end

local function isGovernmentBillingAllowed(source)
    if type(hasFactionPermission) ~= 'function' then
        return false
    end

    local permission = hasFactionPermission(source, {
        factionName = 'government',
        permission = 'government.fees.create'
    })

    if type(permission) ~= 'table' or permission.success ~= true then
        return false
    end

    if type(getCurrentFaction) ~= 'function' then
        return false
    end

    local current = getCurrentFaction(source, {
        factionName = 'government'
    })

    return type(current) == 'table'
        and current.success == true
        and current.data ~= nil
        and current.data.membership ~= nil
        and current.data.dutySession ~= nil
end

local function isTrustedAccountCaller(resourceName)
    return resourceName == 'nexa_jobs_core'
        or resourceName == 'nexa_business'
        or resourceName == 'nexa_fuel'
        or resourceName == NEXA_API.resourceName
end

local function beginAccountTransaction()
    MySQL.query.await('START TRANSACTION')
end

local function commitAccountTransaction()
    MySQL.query.await('COMMIT')
end

local function rollbackAccountTransaction()
    MySQL.query.await('ROLLBACK')
end

local function failTransaction(code, message)
    error(json.encode({
        code = code,
        message = message
    }), 0)
end

local function parseTransactionError(errorValue)
    if type(errorValue) ~= 'string' then
        return 'DATABASE_ERROR', 'Der Vorgang konnte nicht abgeschlossen werden.'
    end

    local decoded = json.decode(errorValue)

    if type(decoded) == 'table' and type(decoded.code) == 'string' then
        return decoded.code, decoded.message or 'Der Vorgang konnte nicht abgeschlossen werden.'
    end

    return 'DATABASE_ERROR', 'Der Vorgang konnte nicht abgeschlossen werden.'
end

local function lockAccounts(accountIds)
    local unique = {}
    local values = {}

    for _, accountId in ipairs(accountIds) do
        local normalized = normalizeId(accountId)

        if normalized ~= nil and unique[normalized] == nil then
            unique[normalized] = true
            values[#values + 1] = normalized
        end
    end

    table.sort(values)

    if #values == 0 then
        return {}
    end

    local placeholders = {}

    for index = 1, #values do
        placeholders[index] = '?'
    end

    local rows = MySQL.query.await(([[ 
        SELECT id, account_number, owner_type, owner_id, account_type, balance, currency, is_frozen,
            created_at, updated_at
        FROM accounts
        WHERE id IN (%s)
        ORDER BY id ASC
        FOR UPDATE
    ]]):format(table.concat(placeholders, ',')), values)

    local locked = {}

    for _, row in ipairs(rows or {}) do
        locked[tonumber(row.id)] = mapAccount(row)
    end

    return locked
end

local function ensureCreditCapacity(account, amount)
    local balance = tonumber(account.balance)

    if balance == nil or balance > accountLimits.maxSignedBigInt - amount then
        failTransaction('CONFLICT', 'Der Zielkontostand waere zu hoch.')
    end
end

local function insertLedger(entry)
    return MySQL.insert.await([[
        INSERT INTO economy_ledger (
            transaction_id, from_account_id, to_account_id, amount, reason, category,
            actor_character_id, actor_player_id, resource_name, metadata, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        entry.transactionId,
        entry.fromAccountId,
        entry.toAccountId,
        entry.amount,
        entry.reason,
        entry.category,
        entry.actorCharacterId,
        entry.actorPlayerId,
        entry.resourceName,
        encodeMetadata(entry.metadata)
    })
end

local function insertBankTransaction(ledgerId, accountId, direction, amount, label)
    MySQL.insert.await([[
        INSERT INTO bank_transactions (ledger_id, account_id, direction, amount, label, created_at)
        VALUES (?, ?, ?, ?, ?, NOW())
    ]], {
        ledgerId,
        accountId,
        direction,
        amount,
        label
    })
end

local function executeLockedLedgerTransaction(entry)
    beginAccountTransaction()

    local ok, result = pcall(function()
        local locked = lockAccounts({
            entry.fromAccountId,
            entry.toAccountId
        })

        local fromAccount = entry.fromAccountId ~= nil and locked[tonumber(entry.fromAccountId)] or nil
        local toAccount = entry.toAccountId ~= nil and locked[tonumber(entry.toAccountId)] or nil

        if entry.fromAccountId ~= nil and fromAccount == nil then
            failTransaction('NOT_FOUND', 'Quellkonto wurde nicht gefunden.')
        end

        if entry.toAccountId ~= nil and toAccount == nil then
            failTransaction('NOT_FOUND', 'Zielkonto wurde nicht gefunden.')
        end

        if fromAccount ~= nil then
            if fromAccount.is_frozen then
                failTransaction('CONFLICT', 'Das Quellkonto ist gesperrt.')
            end

            if tonumber(fromAccount.balance) < entry.amount then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end

            local debited = MySQL.update.await([[
                UPDATE accounts
                SET balance = balance - ?, updated_at = NOW()
                WHERE id = ? AND balance >= ?
            ]], {
                entry.amount,
                fromAccount.id,
                entry.amount
            })

            if debited ~= 1 then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end
        end

        if toAccount ~= nil then
            if toAccount.is_frozen then
                failTransaction('CONFLICT', 'Das Zielkonto ist gesperrt.')
            end

            ensureCreditCapacity(toAccount, entry.amount)

            local credited = MySQL.update.await([[
                UPDATE accounts
                SET balance = balance + ?, updated_at = NOW()
                WHERE id = ? AND balance <= ?
            ]], {
                entry.amount,
                toAccount.id,
                accountLimits.maxSignedBigInt - entry.amount
            })

            if credited ~= 1 then
                failTransaction('CONFLICT', 'Der Zielkontostand waere zu hoch.')
            end
        end

        local ledgerId = insertLedger(entry)

        if fromAccount ~= nil then
            insertBankTransaction(ledgerId, fromAccount.id, 'out', entry.amount, entry.label)
        end

        if toAccount ~= nil then
            insertBankTransaction(ledgerId, toAccount.id, 'in', entry.amount, entry.label)
        end

        return ledgerId
    end)

    if ok then
        commitAccountTransaction()
        return true, result
    end

    rollbackAccountTransaction()
    local code, message = parseTransactionError(result)
    return false, code, message
end

local getLedgerByTransactionId

function NexaAccountExecuteVehiclePurchase(source, payload, createVehicle)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' or type(createVehicle) ~= 'function' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Kaufdaten.', nil, nil, nil)
    end

    local fromAccount = getAccountReference(payload, 'accountId', 'accountNumber')
    local amount = normalizeAmount(payload.amount)
    local reason = normalizeText(payload.reason, 'Fahrzeugkauf')
    local transactionId = normalizeText(payload.transactionId, nil) or buildTransactionId(payload.transactionPrefix or 'vehicle_purchase')

    if fromAccount == nil or amount == nil or reason == nil or #reason > accountLimits.maxReasonLength or transactionId == nil or #transactionId > 64 then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Kaufdaten.', nil, nil, nil)
    end

    if not hasAccountPermission(source, actor.id, fromAccount, 'transfer') then
        return respond(false, 'NO_PERMISSION', 'Du darfst dieses Konto nicht fuer den Fahrzeugkauf verwenden.', nil, nil, nil)
    end

    local success, result = pcall(function()
        beginAccountTransaction()

        local transactionOk, transactionResult = pcall(function()
            local lockedAccounts = lockAccounts({
                fromAccount.id
            })
            local lockedFromAccount = lockedAccounts[tonumber(fromAccount.id)]

            if lockedFromAccount == nil then
                failTransaction('NOT_FOUND', 'Quellkonto wurde nicht gefunden.')
            end

            if lockedFromAccount.is_frozen then
                failTransaction('CONFLICT', 'Das Konto ist gesperrt.')
            end

            if tonumber(lockedFromAccount.balance) < amount then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end

            local debited = MySQL.update.await([[
                UPDATE accounts
                SET balance = balance - ?, updated_at = NOW()
                WHERE id = ? AND balance >= ?
            ]], {
                amount,
                lockedFromAccount.id,
                amount
            })

            if debited ~= 1 then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end

            local ledgerId = insertLedger({
                transactionId = transactionId,
                fromAccountId = lockedFromAccount.id,
                toAccountId = nil,
                amount = amount,
                reason = reason,
                label = reason,
                category = 'vehicle_purchase',
                actorCharacterId = actor.id,
                actorPlayerId = actor.player_id,
                resourceName = payload.resourceName or 'nexa_vehicledealer',
                metadata = payload.metadata or {}
            })

            insertBankTransaction(ledgerId, lockedFromAccount.id, 'out', amount, reason)

            local vehicleData, vehicleCode, vehicleMessage = createVehicle({
                actor = actor,
                ledgerId = ledgerId,
                transactionId = transactionId,
                fromAccount = lockedFromAccount,
                amount = amount
            })

            if vehicleData == nil then
                failTransaction(vehicleCode or 'DATABASE_ERROR', vehicleMessage or 'Fahrzeug konnte nicht erstellt werden.')
            end

            return {
                ledgerId = ledgerId,
                vehicle = vehicleData.vehicle,
                key = vehicleData.key,
                garageState = vehicleData.garageState
            }
        end)

        if transactionOk then
            commitAccountTransaction()
            return transactionResult
        end

        rollbackAccountTransaction()
        error(transactionResult, 0)
    end)

    if not success then
        local code, message = parseTransactionError(result)

        logApi('error', 'Fahrzeugkauf konnte nicht ausgefuehrt werden.', {
            source = source,
            error = result,
            transactionId = transactionId
        })

        return respond(false, code, message or 'Fahrzeugkauf konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local ledger = getLedgerByTransactionId(transactionId)
    local auditId = writeAccountAudit('account.vehiclePurchase', actor, fromAccount.id, {
        transactionId = transactionId,
        amount = amount,
        vehicleId = result.vehicle and result.vehicle.id or nil
    })

    return respond(true, 'OK', 'Fahrzeugkauf wurde bezahlt.', {
        ledger = ledger,
        vehicle = result.vehicle,
        key = result.key,
        garageState = result.garageState
    }, nil, auditId)
end

function NexaAccountExecutePropertyPurchase(source, payload, assignProperty)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' or type(assignProperty) ~= 'function' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Immobiliendaten.', nil, nil, nil)
    end

    local fromAccount = getAccountReference(payload, 'accountId', 'accountNumber')
    local reason = normalizeText(payload.reason, 'Immobilientransaktion')
    local transactionId = normalizeText(payload.transactionId, nil) or buildTransactionId(payload.transactionPrefix or 'property_transaction')

    if fromAccount == nil or reason == nil or #reason > accountLimits.maxReasonLength or transactionId == nil or #transactionId > 64 then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zahlungsdaten.', nil, nil, nil)
    end

    if not hasAccountPermission(source, actor.id, fromAccount, 'transfer') then
        return respond(false, 'NO_PERMISSION', 'Du darfst dieses Konto nicht fuer Immobilienzahlungen nutzen.', nil, nil, nil)
    end

    local success, result = pcall(function()
        beginAccountTransaction()

        local transactionOk, transactionResult = pcall(function()
            local lockedAccounts = lockAccounts({
                fromAccount.id
            })
            local lockedFromAccount = lockedAccounts[tonumber(fromAccount.id)]

            if lockedFromAccount == nil then
                failTransaction('NOT_FOUND', 'Quellkonto wurde nicht gefunden.')
            end

            if lockedFromAccount.is_frozen then
                failTransaction('CONFLICT', 'Das Konto ist gesperrt.')
            end

            local plan, planCode, planMessage = assignProperty({
                stage = 'prepare',
                actor = actor,
                transactionId = transactionId,
                fromAccount = lockedFromAccount
            })

            if plan == nil then
                failTransaction(planCode or 'DATABASE_ERROR', planMessage or 'Immobilientransaktion konnte nicht vorbereitet werden.')
            end

            local amount = normalizeAmount(plan.amount)
            local propertyReason = normalizeText(plan.reason, reason)

            if amount == nil or propertyReason == nil or #propertyReason > accountLimits.maxReasonLength then
                failTransaction('INVALID_INPUT', 'Ungueltige Zahlungsdaten.')
            end

            if tonumber(lockedFromAccount.balance) < amount then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end

            local debited = MySQL.update.await([[
                UPDATE accounts
                SET balance = balance - ?, updated_at = NOW()
                WHERE id = ? AND balance >= ?
            ]], {
                amount,
                lockedFromAccount.id,
                amount
            })

            if debited ~= 1 then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end

            local ledgerId = insertLedger({
                transactionId = transactionId,
                fromAccountId = lockedFromAccount.id,
                toAccountId = nil,
                amount = amount,
                reason = propertyReason,
                label = propertyReason,
                category = plan.category or payload.category or 'property_transaction',
                actorCharacterId = actor.id,
                actorPlayerId = actor.player_id,
                resourceName = payload.resourceName or 'nexa_housing',
                metadata = plan.metadata or payload.metadata or {}
            })

            insertBankTransaction(ledgerId, lockedFromAccount.id, 'out', amount, propertyReason)

            local propertyData, propertyCode, propertyMessage = assignProperty({
                stage = 'commit',
                actor = actor,
                ledgerId = ledgerId,
                transactionId = transactionId,
                fromAccount = lockedFromAccount,
                amount = amount,
                plan = plan
            })

            if propertyData == nil then
                failTransaction(propertyCode or 'DATABASE_ERROR', propertyMessage or 'Immobilientransaktion konnte nicht gespeichert werden.')
            end

            return {
                ledgerId = ledgerId,
                property = propertyData.property,
                propertyTransactionId = propertyData.propertyTransactionId,
                transactionNumber = propertyData.transactionNumber,
                amount = amount,
                accessType = propertyData.accessType,
                status = propertyData.status
            }
        end)

        if transactionOk then
            commitAccountTransaction()
            return transactionResult
        end

        rollbackAccountTransaction()
        error(transactionResult, 0)
    end)

    if not success then
        local code, message = parseTransactionError(result)

        logApi('error', 'Immobilientransaktion konnte nicht ausgefuehrt werden.', {
            source = source,
            error = result,
            transactionId = transactionId
        })

        return respond(false, code, message or 'Immobilientransaktion konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local ledger = getLedgerByTransactionId(transactionId)
    local auditId = writeAccountAudit('account.propertyTransaction', actor, fromAccount.id, {
        transactionId = transactionId,
        amount = result.amount,
        propertyTransactionId = result.propertyTransactionId,
        propertyUnitId = result.property and result.property.id or nil
    })

    return respond(true, 'OK', 'Immobilienzahlung wurde ausgefuehrt.', {
        ledger = ledger,
        property = result.property,
        propertyTransactionId = result.propertyTransactionId,
        transactionNumber = result.transactionNumber,
        amount = result.amount,
        accessType = result.accessType,
        status = result.status
    }, nil, auditId)
end

function NexaAccountExecuteFuelPurchase(source, payload, updateFuel)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' or type(updateFuel) ~= 'function' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Tankdaten.', nil, nil, nil)
    end

    local fromAccount = getAccountReference(payload, 'accountId', 'accountNumber')
    local reason = normalizeText(payload.reason, 'Kraftstoff')
    local transactionId = normalizeText(payload.transactionId, nil) or buildTransactionId(payload.transactionPrefix or 'fuel_purchase')

    if fromAccount == nil or reason == nil or #reason > accountLimits.maxReasonLength or transactionId == nil or #transactionId > 64 then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zahlungsdaten.', nil, nil, nil)
    end

    if not hasAccountPermission(source, actor.id, fromAccount, 'transfer') then
        return respond(false, 'NO_PERMISSION', 'Du darfst dieses Konto nicht fuer Kraftstoff nutzen.', nil, nil, nil)
    end

    local success, result = pcall(function()
        beginAccountTransaction()

        local transactionOk, transactionResult = pcall(function()
            local fuelPlan, fuelCode, fuelMessage = updateFuel({
                stage = 'prepare',
                actor = actor,
                transactionId = transactionId,
                fromAccount = fromAccount
            })

            if fuelPlan == nil then
                failTransaction(fuelCode or 'DATABASE_ERROR', fuelMessage or 'Tankvorgang konnte nicht vorbereitet werden.')
            end

            local amount = normalizeAmount(fuelPlan.amount)
            local fuelReason = normalizeText(fuelPlan.reason, reason)

            if amount == nil or fuelReason == nil or #fuelReason > accountLimits.maxReasonLength then
                failTransaction('INVALID_INPUT', 'Ungueltige Zahlungsdaten.')
            end

            local lockedAccounts = lockAccounts({
                fromAccount.id
            })
            local lockedFromAccount = lockedAccounts[tonumber(fromAccount.id)]

            if lockedFromAccount == nil then
                failTransaction('NOT_FOUND', 'Quellkonto wurde nicht gefunden.')
            end

            if lockedFromAccount.is_frozen then
                failTransaction('CONFLICT', 'Das Konto ist gesperrt.')
            end

            if tonumber(lockedFromAccount.balance) < amount then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end

            local debited = MySQL.update.await([[
                UPDATE accounts
                SET balance = balance - ?, updated_at = NOW()
                WHERE id = ? AND balance >= ?
            ]], {
                amount,
                lockedFromAccount.id,
                amount
            })

            if debited ~= 1 then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end

            local ledgerId = insertLedger({
                transactionId = transactionId,
                fromAccountId = lockedFromAccount.id,
                toAccountId = nil,
                amount = amount,
                reason = fuelReason,
                label = fuelReason,
                category = 'fuel_purchase',
                actorCharacterId = actor.id,
                actorPlayerId = actor.player_id,
                resourceName = payload.resourceName or 'nexa_fuel',
                metadata = fuelPlan.metadata or payload.metadata or {}
            })

            insertBankTransaction(ledgerId, lockedFromAccount.id, 'out', amount, fuelReason)

            local fuelData, fuelCode, fuelMessage = updateFuel({
                stage = 'commit',
                actor = actor,
                ledgerId = ledgerId,
                transactionId = transactionId,
                fromAccount = lockedFromAccount,
                amount = amount,
                plan = fuelPlan
            })

            if fuelData == nil then
                failTransaction(fuelCode or 'DATABASE_ERROR', fuelMessage or 'Tankvorgang konnte nicht gespeichert werden.')
            end

            return {
                ledgerId = ledgerId,
                fuel = fuelData
            }
        end)

        if transactionOk then
            commitAccountTransaction()
            return transactionResult
        end

        rollbackAccountTransaction()
        error(transactionResult, 0)
    end)

    if not success then
        local code, message = parseTransactionError(result)

        logApi('error', 'Tankvorgang konnte nicht ausgefuehrt werden.', {
            source = source,
            error = result,
            transactionId = transactionId
        })

        return respond(false, code, message or 'Tankvorgang konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local ledger = getLedgerByTransactionId(transactionId)
    local auditId = writeAccountAudit('account.fuelPurchase', actor, fromAccount.id, {
        transactionId = transactionId,
        amount = result.fuel and result.fuel.amount or ledger and ledger.amount or nil,
        vehicleId = result.fuel and result.fuel.vehicleId or nil
    })

    return respond(true, 'OK', 'Tankvorgang wurde bezahlt.', {
        ledger = ledger,
        fuel = result.fuel
    }, nil, auditId)
end

function NexaAccountExecuteImpoundRelease(source, payload, releaseVehicle)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' or type(releaseVehicle) ~= 'function' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Freigabedaten.', nil, nil, nil)
    end

    local fromAccount = getAccountReference(payload, 'accountId', 'accountNumber')
    local reason = normalizeText(payload.reason, 'Fahrzeugfreigabe')
    local transactionId = normalizeText(payload.transactionId, nil) or buildTransactionId(payload.transactionPrefix or 'impound_release')

    if fromAccount == nil or reason == nil or #reason > accountLimits.maxReasonLength or transactionId == nil or #transactionId > 64 then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Zahlungsdaten.', nil, nil, nil)
    end

    if not hasAccountPermission(source, actor.id, fromAccount, 'transfer') then
        return respond(false, 'NO_PERMISSION', 'Du darfst dieses Konto nicht fuer die Fahrzeugfreigabe nutzen.', nil, nil, nil)
    end

    local success, result = pcall(function()
        beginAccountTransaction()

        local transactionOk, transactionResult = pcall(function()
            local releasePlan, releaseCode, releaseMessage = releaseVehicle({
                stage = 'prepare',
                actor = actor,
                transactionId = transactionId,
                fromAccount = fromAccount
            })

            if releasePlan == nil then
                failTransaction(releaseCode or 'DATABASE_ERROR', releaseMessage or 'Fahrzeugfreigabe konnte nicht vorbereitet werden.')
            end

            local amount = normalizeAmount(releasePlan.amount)
            local releaseReason = normalizeText(releasePlan.reason, reason)

            if amount == nil or releaseReason == nil or #releaseReason > accountLimits.maxReasonLength then
                failTransaction('INVALID_INPUT', 'Ungueltige Zahlungsdaten.')
            end

            local lockedAccounts = lockAccounts({
                fromAccount.id
            })
            local lockedFromAccount = lockedAccounts[tonumber(fromAccount.id)]

            if lockedFromAccount == nil then
                failTransaction('NOT_FOUND', 'Quellkonto wurde nicht gefunden.')
            end

            if lockedFromAccount.is_frozen then
                failTransaction('CONFLICT', 'Das Konto ist gesperrt.')
            end

            if tonumber(lockedFromAccount.balance) < amount then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end

            local debited = MySQL.update.await([[
                UPDATE accounts
                SET balance = balance - ?, updated_at = NOW()
                WHERE id = ? AND balance >= ?
            ]], {
                amount,
                lockedFromAccount.id,
                amount
            })

            if debited ~= 1 then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end

            local ledgerId = insertLedger({
                transactionId = transactionId,
                fromAccountId = lockedFromAccount.id,
                toAccountId = nil,
                amount = amount,
                reason = releaseReason,
                label = releaseReason,
                category = 'impound_release',
                actorCharacterId = actor.id,
                actorPlayerId = actor.player_id,
                resourceName = payload.resourceName or 'nexa_impound',
                metadata = releasePlan.metadata or payload.metadata or {}
            })

            insertBankTransaction(ledgerId, lockedFromAccount.id, 'out', amount, releaseReason)

            local releaseData, releaseCode, releaseMessage = releaseVehicle({
                stage = 'commit',
                actor = actor,
                ledgerId = ledgerId,
                transactionId = transactionId,
                fromAccount = lockedFromAccount,
                amount = amount,
                plan = releasePlan
            })

            if releaseData == nil then
                failTransaction(releaseCode or 'DATABASE_ERROR', releaseMessage or 'Fahrzeugfreigabe konnte nicht gespeichert werden.')
            end

            return {
                ledgerId = ledgerId,
                release = releaseData
            }
        end)

        if transactionOk then
            commitAccountTransaction()
            return transactionResult
        end

        rollbackAccountTransaction()
        error(transactionResult, 0)
    end)

    if not success then
        local code, message = parseTransactionError(result)

        logApi('error', 'Fahrzeugfreigabe konnte nicht ausgefuehrt werden.', {
            source = source,
            error = result,
            transactionId = transactionId
        })

        return respond(false, code, message or 'Fahrzeugfreigabe konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local ledger = getLedgerByTransactionId(transactionId)
    local auditId = writeAccountAudit('account.impoundRelease', actor, fromAccount.id, {
        transactionId = transactionId,
        amount = result.release and result.release.amount or ledger and ledger.amount or nil,
        vehicleId = result.release and result.release.vehicleId or nil
    })

    return respond(true, 'OK', 'Fahrzeugfreigabe wurde bezahlt.', {
        ledger = ledger,
        release = result.release
    }, nil, auditId)
end

function getLedgerByTransactionId(transactionId)
    return MySQL.single.await([[
        SELECT id, transaction_id, from_account_id, to_account_id, amount, reason, category, created_at
        FROM economy_ledger
        WHERE transaction_id = ?
        LIMIT 1
    ]], {
        transactionId
    })
end

function createPrivateAccount(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local accountType = normalizeText(payload and payload.accountType or 'checking', 'checking')

    if accountType ~= 'checking' and accountType ~= 'savings' then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Kontotyp.', nil, nil, nil)
    end

    local existing = MySQL.scalar.await([[
        SELECT id
        FROM accounts
        WHERE owner_type = 'character' AND owner_id = ? AND account_type = ?
        LIMIT 1
    ]], {
        actor.id,
        accountType
    })

    if existing ~= nil then
        return respond(false, 'CONFLICT', 'Dieses Konto existiert bereits.', nil, nil, nil)
    end

    local accountNumber = generateAccountNumber()

    if accountNumber == nil then
        return respond(false, 'CONFLICT', 'Kontonummer konnte nicht erzeugt werden.', nil, nil, nil)
    end

    local success, result = pcall(function()
        return MySQL.transaction.await({
            {
                query = [[
                    INSERT INTO accounts (account_number, owner_type, owner_id, account_type, balance, currency, created_at, updated_at)
                    VALUES (?, 'character', ?, ?, 0, 'USD', NOW(), NOW())
                ]],
                values = { accountNumber, actor.id, accountType }
            },
            {
                query = [[
                    INSERT INTO account_members (account_id, character_id, role, permissions, granted_by_character_id, created_at)
                    SELECT id, ?, 'owner', JSON_ARRAY('view', 'transfer', 'pay_invoice', 'manage_members'), ?, NOW()
                    FROM accounts
                    WHERE account_number = ?
                    LIMIT 1
                ]],
                values = { actor.id, actor.id, accountNumber }
            }
        })
    end)

    if not success or result == false then
        logApi('error', 'Privates Konto konnte nicht erstellt werden.', {
            source = source,
            characterId = actor.id,
            error = result
        })

        return respond(false, 'DATABASE_ERROR', 'Konto konnte nicht erstellt werden.', nil, nil, nil)
    end

    local account = getAccountByNumber(accountNumber)
    local auditId = writeAccountAudit('account.createPrivate', actor, account and account.id or nil, {
        accountType = accountType,
        accountNumber = accountNumber
    })

    return respond(true, 'CREATED', 'Konto wurde erstellt.', {
        account = account
    }, nil, auditId)
end

function listAccounts(source)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local rows = MySQL.query.await([[
        SELECT DISTINCT a.id, a.account_number, a.owner_type, a.owner_id, a.account_type, a.balance,
            a.currency, a.is_frozen, a.created_at, a.updated_at,
            CASE
                WHEN a.owner_type = 'character' AND a.owner_id = ? THEN 'owner'
                ELSE am.role
            END AS role
        FROM accounts a
        LEFT JOIN account_members am
            ON am.account_id = a.id
            AND am.character_id = ?
            AND am.revoked_at IS NULL
            AND (am.expires_at IS NULL OR am.expires_at > NOW())
        WHERE (a.owner_type = 'character' AND a.owner_id = ?)
            OR am.id IS NOT NULL
        ORDER BY a.created_at ASC
    ]], {
        actor.id,
        actor.id,
        actor.id
    })

    local accounts = {}

    for _, row in ipairs(rows or {}) do
        accounts[#accounts + 1] = mapAccount(row)
    end

    return respond(true, 'OK', 'Konten wurden geladen.', {
        accounts = accounts
    }, nil, nil)
end

function getAccountTransactions(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local account = getAccountReference(payload, 'accountId', 'accountNumber')

    if account == nil then
        return respond(false, 'NOT_FOUND', 'Konto wurde nicht gefunden.', nil, nil, nil)
    end

    if not hasAccountPermission(source, actor.id, account, 'view') then
        return respond(false, 'NO_PERMISSION', 'Du hast keinen Zugriff auf dieses Konto.', nil, nil, nil)
    end

    local limit = normalizeId(payload.limit) or 25

    if limit > accountLimits.maxHistoryLimit then
        limit = accountLimits.maxHistoryLimit
    end

    local rows = MySQL.query.await([[
        SELECT id, ledger_id, account_id, direction, amount, label, created_at
        FROM bank_transactions
        WHERE account_id = ?
        ORDER BY created_at DESC, id DESC
        LIMIT ?
    ]], {
        account.id,
        limit
    })

    return respond(true, 'OK', 'Transaktionen wurden geladen.', {
        transactions = rows or {}
    }, {
        limit = limit
    }, nil)
end

function transferMoney(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local fromAccount = getAccountReference(payload, 'fromAccountId', 'fromAccountNumber')
    local toAccount = getAccountReference(payload, 'toAccountId', 'toAccountNumber')
    local amount = normalizeAmount(payload.amount)
    local reason = normalizeText(payload.reason, 'Ueberweisung')

    if fromAccount == nil or toAccount == nil or amount == nil or reason == nil or #reason > accountLimits.maxReasonLength then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Ueberweisungsdaten.', nil, nil, nil)
    end

    if fromAccount.id == toAccount.id then
        return respond(false, 'CONFLICT', 'Quell- und Zielkonto muessen verschieden sein.', nil, nil, nil)
    end

    if fromAccount.is_frozen or toAccount.is_frozen then
        return respond(false, 'CONFLICT', 'Mindestens ein Konto ist gesperrt.', nil, nil, nil)
    end

    if not hasAccountPermission(source, actor.id, fromAccount, 'transfer') then
        return respond(false, 'NO_PERMISSION', 'Du darfst von diesem Konto nicht ueberweisen.', nil, nil, nil)
    end

    if tonumber(fromAccount.balance) < amount then
        return respond(false, 'INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.', nil, nil, nil)
    end

    local transactionId = buildTransactionId('bank')
    local success, result, transactionMessage = executeLockedLedgerTransaction({
        transactionId = transactionId,
        fromAccountId = fromAccount.id,
        toAccountId = toAccount.id,
        amount = amount,
        reason = reason,
        label = reason,
        category = 'transfer',
        actorCharacterId = actor.id,
        actorPlayerId = actor.player_id,
        resourceName = NEXA_API.resourceName,
        metadata = {
            source = source,
            fromAccountNumber = fromAccount.account_number,
            toAccountNumber = toAccount.account_number
        }
    })

    if not success then
        logApi('error', 'Ueberweisung konnte nicht ausgefuehrt werden.', {
            source = source,
            fromAccountId = fromAccount.id,
            toAccountId = toAccount.id,
            error = result
        })

        return respond(false, result, transactionMessage or 'Ueberweisung konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local ledger = getLedgerByTransactionId(transactionId)
    local auditId = writeAccountAudit('account.transfer', actor, fromAccount.id, {
        transactionId = transactionId,
        ledgerId = ledger and ledger.id or nil,
        toAccountId = toAccount.id,
        amount = amount
    })

    return respond(true, 'OK', 'Ueberweisung wurde ausgefuehrt.', {
        ledger = ledger
    }, nil, auditId)
end

function addMoney(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if not hasGlobalPermission(source, 'account.admin.credit') then
        return respond(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local account = getAccountReference(payload, 'accountId', 'accountNumber')
    local amount = normalizeAmount(payload.amount)
    local reason = normalizeText(payload.reason, 'Einzahlung')

    if account == nil or amount == nil or reason == nil or #reason > accountLimits.maxReasonLength then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Buchungsdaten.', nil, nil, nil)
    end

    local transactionId = buildTransactionId('credit')
    local success, result, transactionMessage = executeLockedLedgerTransaction({
        transactionId = transactionId,
        fromAccountId = nil,
        toAccountId = account.id,
        amount = amount,
        reason = reason,
        label = reason,
        category = payload.category or 'credit',
        actorCharacterId = actor.id,
        actorPlayerId = actor.player_id,
        resourceName = NEXA_API.resourceName,
        metadata = payload.metadata or {}
    })

    if not success then
        return respond(false, result, transactionMessage or 'Buchung konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local ledger = getLedgerByTransactionId(transactionId)
    return respond(true, 'OK', 'Buchung wurde ausgefuehrt.', {
        ledger = ledger
    }, nil, writeAccountAudit('account.addMoney', actor, account.id, {
        transactionId = transactionId,
        amount = amount
    }))
end

function addSystemMoney(source, payload)
    local caller = getInvokingResourceName()

    if not isTrustedAccountCaller(caller) then
        return respond(false, 'NO_PERMISSION', 'Diese Resource darf keine Systembuchung ausloesen.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local account = getAccountReference(payload, 'accountId', 'accountNumber')
    local amount = normalizeAmount(payload.amount)
    local reason = normalizeText(payload.reason, 'Systembuchung')

    if account == nil or amount == nil or reason == nil or #reason > accountLimits.maxReasonLength then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Buchungsdaten.', nil, nil, nil)
    end

    local transactionId = normalizeText(payload.transactionId, nil) or buildTransactionId(payload.transactionPrefix or 'system_credit')

    if #transactionId > 64 then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Transaktionsreferenz.', nil, nil, nil)
    end

    local success, result, transactionMessage = executeLockedLedgerTransaction({
        transactionId = transactionId,
        fromAccountId = nil,
        toAccountId = account.id,
        amount = amount,
        reason = reason,
        label = reason,
        category = payload.category or 'system_credit',
        actorCharacterId = actor.id,
        actorPlayerId = actor.player_id,
        resourceName = caller,
        metadata = payload.metadata or {}
    })

    if not success then
        if getLedgerByTransactionId(transactionId) ~= nil then
            return respond(false, 'CONFLICT', 'Diese Buchung wurde bereits ausgefuehrt.', nil, nil, nil)
        end

        return respond(false, result, transactionMessage or 'Buchung konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local ledger = getLedgerByTransactionId(transactionId)
    return respond(true, 'OK', 'Buchung wurde ausgefuehrt.', {
        ledger = ledger
    }, nil, writeAccountAudit('account.addSystemMoney', actor, account.id, {
        transactionId = transactionId,
        amount = amount,
        caller = caller
    }))
end

function removeSystemMoney(source, payload)
    local caller = getInvokingResourceName()

    if caller ~= NEXA_API.resourceName then
        return respond(false, 'NO_PERMISSION', 'Diese Resource darf keine Systemabbuchung ausloesen.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local account = getAccountReference(payload, 'accountId', 'accountNumber')
    local amount = normalizeAmount(payload.amount)
    local reason = normalizeText(payload.reason, 'Systemabbuchung')

    if account == nil or amount == nil or reason == nil or #reason > accountLimits.maxReasonLength then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Buchungsdaten.', nil, nil, nil)
    end

    if not hasAccountPermission(source, actor.id, account, 'transfer') then
        return respond(false, 'NO_PERMISSION', 'Du darfst dieses Konto nicht verwenden.', nil, nil, nil)
    end

    local transactionId = normalizeText(payload.transactionId, nil) or buildTransactionId(payload.transactionPrefix or 'system_debit')

    if #transactionId > 64 then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Transaktionsreferenz.', nil, nil, nil)
    end

    local success, result, transactionMessage = executeLockedLedgerTransaction({
        transactionId = transactionId,
        fromAccountId = account.id,
        toAccountId = nil,
        amount = amount,
        reason = reason,
        label = reason,
        category = payload.category or 'system_debit',
        actorCharacterId = actor.id,
        actorPlayerId = actor.player_id,
        resourceName = caller,
        metadata = payload.metadata or {}
    })

    if not success then
        if getLedgerByTransactionId(transactionId) ~= nil then
            return respond(false, 'CONFLICT', 'Diese Buchung wurde bereits ausgefuehrt.', nil, nil, nil)
        end

        return respond(false, result, transactionMessage or 'Buchung konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local ledger = getLedgerByTransactionId(transactionId)
    return respond(true, 'OK', 'Buchung wurde ausgefuehrt.', {
        ledger = ledger
    }, nil, writeAccountAudit('account.removeSystemMoney', actor, account.id, {
        transactionId = transactionId,
        amount = amount,
        caller = caller
    }))
end

function createBusinessAccount(source, payload)
    local caller = getInvokingResourceName()

    if caller ~= 'nexa_business' and caller ~= NEXA_API.resourceName then
        return respond(false, 'NO_PERMISSION', 'Diese Resource darf keine Firmenkonten erstellen.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local businessId = normalizeId(payload.businessId)
    local accountRole = normalizeText(payload.accountRole, 'primary')

    if businessId == nil or accountRole == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Firmendaten.', nil, nil, nil)
    end

    if accountRole ~= 'primary' and accountRole ~= 'payroll' and accountRole ~= 'tax' and accountRole ~= 'reserve' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Kontorolle.', nil, nil, nil)
    end

    local business = MySQL.single.await([[
        SELECT id, business_code, name, status
        FROM businesses
        WHERE id = ?
        LIMIT 1
    ]], {
        businessId
    })

    if business == nil then
        return respond(false, 'NOT_FOUND', 'Firma wurde nicht gefunden.', nil, nil, nil)
    end

    if business.status ~= 'active' then
        return respond(false, 'CONFLICT', 'Firma ist nicht aktiv.', nil, nil, nil)
    end

    local existing = MySQL.scalar.await([[
        SELECT id
        FROM business_accounts
        WHERE business_id = ? AND account_role = ?
        LIMIT 1
    ]], {
        businessId,
        accountRole
    })

    if existing ~= nil then
        return respond(false, 'CONFLICT', 'Dieses Firmenkonto existiert bereits.', nil, nil, nil)
    end

    local accountNumber = generateAccountNumber()

    if accountNumber == nil then
        return respond(false, 'CONFLICT', 'Kontonummer konnte nicht erzeugt werden.', nil, nil, nil)
    end

    local success, result = pcall(function()
        return MySQL.transaction.await({
            {
                query = [[
                    INSERT INTO accounts (account_number, owner_type, owner_id, account_type, balance, currency, created_at, updated_at)
                    VALUES (?, 'business', ?, 'business', 0, 'USD', NOW(), NOW())
                ]],
                values = { accountNumber, businessId }
            },
            {
                query = [[
                    INSERT INTO business_accounts (business_id, account_id, account_role, is_active, created_at)
                    SELECT ?, id, ?, TRUE, NOW()
                    FROM accounts
                    WHERE account_number = ?
                    LIMIT 1
                ]],
                values = { businessId, accountRole, accountNumber }
            },
            {
                query = [[
                    INSERT INTO account_members (account_id, character_id, role, permissions, granted_by_character_id, created_at)
                    SELECT id, ?, 'owner', JSON_ARRAY('view', 'transfer', 'pay_invoice', 'manage_members'), ?, NOW()
                    FROM accounts
                    WHERE account_number = ?
                    LIMIT 1
                ]],
                values = { actor.id, actor.id, accountNumber }
            }
        })
    end)

    if not success or result == false then
        logApi('error', 'Firmenkonto konnte nicht erstellt werden.', {
            source = source,
            businessId = businessId,
            error = result
        })

        return respond(false, 'DATABASE_ERROR', 'Firmenkonto konnte nicht erstellt werden.', nil, nil, nil)
    end

    local account = getAccountByNumber(accountNumber)
    local auditId = writeAccountAudit('account.createBusiness', actor, account and account.id or nil, {
        businessId = businessId,
        accountRole = accountRole,
        accountNumber = accountNumber
    })

    return respond(true, 'CREATED', 'Firmenkonto wurde erstellt.', {
        account = account
    }, nil, auditId)
end

function createFactionAccount(source, payload)
    local caller = getInvokingResourceName()

    if caller ~= 'nexa_factions_core' and caller ~= NEXA_API.resourceName then
        return respond(false, 'NO_PERMISSION', 'Diese Resource darf keine Fraktionskonten erstellen.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local factionId = normalizeId(payload.factionId)

    if factionId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Fraktionsdaten.', nil, nil, nil)
    end

    local faction = MySQL.single.await([[
        SELECT id, name, label, status
        FROM factions
        WHERE id = ?
        LIMIT 1
    ]], {
        factionId
    })

    if faction == nil then
        return respond(false, 'NOT_FOUND', 'Fraktion wurde nicht gefunden.', nil, nil, nil)
    end

    if faction.status ~= 'active' then
        return respond(false, 'CONFLICT', 'Fraktion ist nicht aktiv.', nil, nil, nil)
    end

    local existing = getPrimaryOwnerAccount('faction', factionId)

    if existing ~= nil then
        return respond(true, 'OK', 'Fraktionskonto ist bereits vorhanden.', {
            account = existing,
            faction = faction
        }, nil, nil)
    end

    local accountNumber = generateAccountNumber()

    if accountNumber == nil then
        return respond(false, 'CONFLICT', 'Kontonummer konnte nicht erzeugt werden.', nil, nil, nil)
    end

    local success, result = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO accounts (account_number, owner_type, owner_id, account_type, balance, currency, created_at, updated_at)
            VALUES (?, 'faction', ?, 'faction', 0, 'USD', NOW(), NOW())
        ]], {
            accountNumber,
            factionId
        })
    end)

    if not success or result == nil then
        logApi('error', 'Fraktionskonto konnte nicht erstellt werden.', {
            source = source,
            factionId = factionId,
            error = result
        })

        return respond(false, 'DATABASE_ERROR', 'Fraktionskonto konnte nicht erstellt werden.', nil, nil, nil)
    end

    local account = getAccountByNumber(accountNumber)
    local auditId = writeAccountAudit('account.createFaction', actor, account and account.id or nil, {
        factionId = factionId,
        accountNumber = accountNumber
    })

    return respond(true, 'CREATED', 'Fraktionskonto wurde erstellt.', {
        account = account,
        faction = faction
    }, nil, auditId)
end

function removeMoney(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if not hasGlobalPermission(source, 'account.admin.debit') then
        return respond(false, 'NO_PERMISSION', 'Du hast dafuer keine Berechtigung.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local account = getAccountReference(payload, 'accountId', 'accountNumber')
    local amount = normalizeAmount(payload.amount)
    local reason = normalizeText(payload.reason, 'Abbuchung')

    if account == nil or amount == nil or reason == nil or #reason > accountLimits.maxReasonLength then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Buchungsdaten.', nil, nil, nil)
    end

    if tonumber(account.balance) < amount then
        return respond(false, 'INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.', nil, nil, nil)
    end

    local transactionId = buildTransactionId('debit')
    local success, result, transactionMessage = executeLockedLedgerTransaction({
        transactionId = transactionId,
        fromAccountId = account.id,
        toAccountId = nil,
        amount = amount,
        reason = reason,
        label = reason,
        category = payload.category or 'debit',
        actorCharacterId = actor.id,
        actorPlayerId = actor.player_id,
        resourceName = NEXA_API.resourceName,
        metadata = payload.metadata or {}
    })

    if not success then
        return respond(false, result, transactionMessage or 'Buchung konnte nicht ausgefuehrt werden.', nil, nil, nil)
    end

    local ledger = getLedgerByTransactionId(transactionId)
    return respond(true, 'OK', 'Buchung wurde ausgefuehrt.', {
        ledger = ledger
    }, nil, writeAccountAudit('account.removeMoney', actor, account.id, {
        transactionId = transactionId,
        amount = amount
    }))
end

function createMedicalInvoice(source, payload)
    local caller = getInvokingResourceName()

    if caller ~= 'nexa_ems' and caller ~= NEXA_API.resourceName then
        return respond(false, 'NO_PERMISSION', 'Diese Resource darf keine medizinischen Rechnungen erstellen.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if not isEmsBillingAllowed(source) then
        return respond(false, 'NO_PERMISSION', 'Du darfst keine medizinischen Rechnungen erstellen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Rechnungsdaten.', nil, nil, nil)
    end

    local characterId = normalizeId(payload.characterId)
    local amount = normalizeAmount(payload.amount)
    local reason = normalizeText(payload.reason, 'Medizinische Behandlung')
    local recordId = normalizeId(payload.recordId)

    if characterId == nil or amount == nil or reason == nil or #reason > accountLimits.maxReasonLength then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Rechnungsdaten.', nil, nil, nil)
    end

    local patient = MySQL.single.await([[ 
        SELECT id, citizenid, firstname, lastname
        FROM characters
        WHERE id = ? AND is_active = TRUE
        LIMIT 1
    ]], {
        characterId
    })

    if patient == nil then
        return respond(false, 'NOT_FOUND', 'Patient wurde nicht gefunden.', nil, nil, nil)
    end

    local faction = MySQL.single.await([[ 
        SELECT id, name, label
        FROM factions
        WHERE name = 'ems' AND status = 'active'
        LIMIT 1
    ]])

    if faction == nil then
        return respond(false, 'NOT_FOUND', 'EMS-Fraktion wurde nicht gefunden.', nil, nil, nil)
    end

    if recordId ~= nil then
        local record = MySQL.single.await([[ 
            SELECT id, character_id
            FROM ems_records
            WHERE id = ? AND character_id = ?
            LIMIT 1
        ]], {
            recordId,
            patient.id
        })

        if record == nil then
            return respond(false, 'NOT_FOUND', 'EMS-Patientenakte wurde nicht gefunden.', nil, nil, nil)
        end
    end

    local invoiceNumber = nil

    for _ = 1, 10 do
        local candidate = buildInvoiceNumber('MED')
        local existing = MySQL.scalar.await('SELECT id FROM invoices WHERE invoice_number = ? LIMIT 1', {
            candidate
        })

        if existing == nil then
            invoiceNumber = candidate
            break
        end
    end

    if invoiceNumber == nil then
        return respond(false, 'CONFLICT', 'Rechnungsnummer konnte nicht erzeugt werden.', nil, nil, nil)
    end

    local invoiceId = MySQL.insert.await([[ 
        INSERT INTO invoices (invoice_number, from_type, from_id, to_character_id, amount, reason, status, due_at, created_at)
        VALUES (?, 'faction', ?, ?, ?, ?, 'open', DATE_ADD(NOW(), INTERVAL 14 DAY), NOW())
    ]], {
        invoiceNumber,
        faction.id,
        patient.id,
        amount,
        reason
    })

    local auditId = writeAccountAudit('account.createMedicalInvoice', actor, nil, {
        invoiceId = invoiceId,
        invoiceNumber = invoiceNumber,
        patientCharacterId = patient.id,
        factionId = faction.id,
        amount = amount,
        reason = reason,
        recordId = recordId
    })

    return respond(true, 'CREATED', 'Medizinische Rechnung wurde erstellt.', {
        invoice = {
            id = invoiceId,
            invoice_number = invoiceNumber,
            from_type = 'faction',
            from_id = faction.id,
            to_character_id = patient.id,
            amount = amount,
            reason = reason,
            status = 'open'
        },
        patient = patient
    }, nil, auditId)
end

function createGovernmentInvoice(source, payload)
    local caller = getInvokingResourceName()

    if caller ~= 'nexa_government' and caller ~= NEXA_API.resourceName then
        return respond(false, 'NO_PERMISSION', 'Diese Resource darf keine Government-Rechnungen erstellen.', nil, nil, nil)
    end

    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if not isGovernmentBillingAllowed(source) then
        return respond(false, 'NO_PERMISSION', 'Du darfst keine Government-Rechnungen erstellen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Rechnungsdaten.', nil, nil, nil)
    end

    local characterId = normalizeId(payload.characterId)
    local amount = normalizeAmount(payload.amount)
    local reason = normalizeText(payload.reason, 'Government-Gebuehr')

    if characterId == nil or amount == nil or reason == nil or #reason > accountLimits.maxReasonLength then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Rechnungsdaten.', nil, nil, nil)
    end

    local citizen = MySQL.single.await([[ 
        SELECT id, citizenid, firstname, lastname
        FROM characters
        WHERE id = ? AND is_active = TRUE
        LIMIT 1
    ]], {
        characterId
    })

    if citizen == nil then
        return respond(false, 'NOT_FOUND', 'Charakter wurde nicht gefunden.', nil, nil, nil)
    end

    local faction = MySQL.single.await([[ 
        SELECT id, name, label
        FROM factions
        WHERE name = 'government' AND status = 'active'
        LIMIT 1
    ]])

    if faction == nil then
        return respond(false, 'NOT_FOUND', 'Government-Fraktion wurde nicht gefunden.', nil, nil, nil)
    end

    local invoiceNumber = nil

    for _ = 1, 10 do
        local candidate = buildInvoiceNumber('GOV')
        local existing = MySQL.scalar.await('SELECT id FROM invoices WHERE invoice_number = ? LIMIT 1', {
            candidate
        })

        if existing == nil then
            invoiceNumber = candidate
            break
        end
    end

    if invoiceNumber == nil then
        return respond(false, 'CONFLICT', 'Rechnungsnummer konnte nicht erzeugt werden.', nil, nil, nil)
    end

    local invoiceId = MySQL.insert.await([[ 
        INSERT INTO invoices (invoice_number, from_type, from_id, to_character_id, amount, reason, status, due_at, created_at)
        VALUES (?, 'faction', ?, ?, ?, ?, 'open', DATE_ADD(NOW(), INTERVAL 14 DAY), NOW())
    ]], {
        invoiceNumber,
        faction.id,
        citizen.id,
        amount,
        reason
    })

    local auditId = writeAccountAudit('account.createGovernmentInvoice', actor, nil, {
        invoiceId = invoiceId,
        invoiceNumber = invoiceNumber,
        citizenCharacterId = citizen.id,
        factionId = faction.id,
        amount = amount,
        reason = reason
    })

    return respond(true, 'CREATED', 'Government-Rechnung wurde erstellt.', {
        invoice = {
            id = invoiceId,
            invoice_number = invoiceNumber,
            from_type = 'faction',
            from_id = faction.id,
            to_character_id = citizen.id,
            amount = amount,
            reason = reason,
            status = 'open'
        },
        citizen = citizen
    }, nil, auditId)
end

function listInvoices(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local limit = normalizeId(payload and payload.limit) or 25

    if limit > accountLimits.maxInvoiceLimit then
        limit = accountLimits.maxInvoiceLimit
    end

    local rows = MySQL.query.await([[
        SELECT id, invoice_number, from_type, from_id, to_character_id, amount, reason, status,
            due_at, paid_at, created_at
        FROM invoices
        WHERE to_character_id = ?
        ORDER BY created_at DESC, id DESC
        LIMIT ?
    ]], {
        actor.id,
        limit
    })

    return respond(true, 'OK', 'Rechnungen wurden geladen.', {
        invoices = rows or {}
    }, {
        limit = limit
    }, nil)
end

function payInvoice(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local invoiceId = normalizeId(payload.invoiceId)
    local fromAccount = getAccountReference(payload, 'fromAccountId', 'fromAccountNumber')

    if invoiceId == nil or fromAccount == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Rechnungsdaten.', nil, nil, nil)
    end

    if not hasAccountPermission(source, actor.id, fromAccount, 'pay_invoice') then
        return respond(false, 'NO_PERMISSION', 'Du darfst diese Rechnung nicht von diesem Konto bezahlen.', nil, nil, nil)
    end

    local invoice = MySQL.single.await([[
        SELECT id, invoice_number, from_type, from_id, to_character_id, amount, reason, status
        FROM invoices
        WHERE id = ? AND to_character_id = ?
        LIMIT 1
    ]], {
        invoiceId,
        actor.id
    })

    if invoice == nil then
        return respond(false, 'NOT_FOUND', 'Rechnung wurde nicht gefunden.', nil, nil, nil)
    end

    if invoice.status ~= 'open' then
        return respond(false, 'CONFLICT', 'Rechnung ist nicht offen.', nil, nil, nil)
    end

    if fromAccount.is_frozen then
        return respond(false, 'CONFLICT', 'Das Konto ist gesperrt.', nil, nil, nil)
    end

    local amount = normalizeAmount(invoice.amount)

    if amount == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Rechnungsbetrag.', nil, nil, nil)
    end

    if tonumber(fromAccount.balance) < amount then
        return respond(false, 'INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.', nil, nil, nil)
    end

    local transactionId = buildTransactionId('invoice')
    local success, result = pcall(function()
        beginAccountTransaction()

        local transactionOk, transactionResult = pcall(function()
            local lockedInvoice = MySQL.single.await([[
                SELECT id, invoice_number, from_type, from_id, to_character_id, amount, reason, status
                FROM invoices
                WHERE id = ? AND to_character_id = ?
                LIMIT 1
                FOR UPDATE
            ]], {
                invoiceId,
                actor.id
            })

            if lockedInvoice == nil then
                failTransaction('NOT_FOUND', 'Rechnung wurde nicht gefunden.')
            end

            if lockedInvoice.status ~= 'open' then
                failTransaction('CONFLICT', 'Rechnung ist nicht offen.')
            end

            local lockedAmount = normalizeAmount(lockedInvoice.amount)

            if lockedAmount == nil then
                failTransaction('INVALID_INPUT', 'Ungueltiger Rechnungsbetrag.')
            end

            local lockedToAccount = getPrimaryOwnerAccount(lockedInvoice.from_type, lockedInvoice.from_id)
            local lockedAccounts = lockAccounts({
                fromAccount.id,
                lockedToAccount and lockedToAccount.id or nil
            })
            local lockedFromAccount = lockedAccounts[tonumber(fromAccount.id)]
            lockedToAccount = lockedToAccount ~= nil and lockedAccounts[tonumber(lockedToAccount.id)] or nil

            if lockedFromAccount == nil then
                failTransaction('NOT_FOUND', 'Quellkonto wurde nicht gefunden.')
            end

            if lockedFromAccount.is_frozen then
                failTransaction('CONFLICT', 'Das Konto ist gesperrt.')
            end

            if tonumber(lockedFromAccount.balance) < lockedAmount then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end

            if lockedToAccount ~= nil then
                if lockedToAccount.is_frozen then
                    failTransaction('CONFLICT', 'Das Zielkonto ist gesperrt.')
                end

                ensureCreditCapacity(lockedToAccount, lockedAmount)
            end

            local debited = MySQL.update.await([[
                UPDATE accounts
                SET balance = balance - ?, updated_at = NOW()
                WHERE id = ? AND balance >= ?
            ]], {
                lockedAmount,
                lockedFromAccount.id,
                lockedAmount
            })

            if debited ~= 1 then
                failTransaction('INSUFFICIENT_FUNDS', 'Nicht genug Guthaben vorhanden.')
            end

            if lockedToAccount ~= nil then
                local credited = MySQL.update.await([[
                    UPDATE accounts
                    SET balance = balance + ?, updated_at = NOW()
                    WHERE id = ? AND balance <= ?
                ]], {
                    lockedAmount,
                    lockedToAccount.id,
                    accountLimits.maxSignedBigInt - lockedAmount
                })

                if credited ~= 1 then
                    failTransaction('CONFLICT', 'Der Zielkontostand waere zu hoch.')
                end
            end

            local ledgerId = insertLedger({
                transactionId = transactionId,
                fromAccountId = lockedFromAccount.id,
                toAccountId = lockedToAccount and lockedToAccount.id or nil,
                amount = lockedAmount,
                reason = lockedInvoice.reason,
                label = lockedInvoice.reason,
                category = 'invoice_payment',
                actorCharacterId = actor.id,
                actorPlayerId = actor.player_id,
                resourceName = NEXA_API.resourceName,
                metadata = {
                    invoiceId = lockedInvoice.id,
                    invoiceNumber = lockedInvoice.invoice_number,
                    fromType = lockedInvoice.from_type,
                    fromId = lockedInvoice.from_id,
                    sink = lockedToAccount == nil,
                    source = source
                }
            })

            insertBankTransaction(ledgerId, lockedFromAccount.id, 'out', lockedAmount, lockedInvoice.reason)

            if lockedToAccount ~= nil then
                insertBankTransaction(ledgerId, lockedToAccount.id, 'in', lockedAmount, lockedInvoice.reason)
            end

            local invoiceUpdated = MySQL.update.await([[
                UPDATE invoices
                SET status = 'paid', paid_at = NOW()
                WHERE id = ? AND status = 'open'
            ]], {
                lockedInvoice.id
            })

            if invoiceUpdated ~= 1 then
                failTransaction('CONFLICT', 'Rechnung ist nicht offen.')
            end

            return ledgerId
        end)

        if transactionOk then
            commitAccountTransaction()
            return transactionResult
        end

        rollbackAccountTransaction()
        error(transactionResult, 0)
    end)

    if not success then
        local code, message = parseTransactionError(result)

        logApi('error', 'Rechnung konnte nicht bezahlt werden.', {
            source = source,
            invoiceId = invoice.id,
            error = result
        })

        return respond(false, code, message or 'Rechnung konnte nicht bezahlt werden.', nil, nil, nil)
    end

    local ledger = getLedgerByTransactionId(transactionId)
    local auditId = writeAccountAudit('account.payInvoice', actor, fromAccount.id, {
        transactionId = transactionId,
        invoiceId = invoice.id,
        amount = amount
    })

    return respond(true, 'OK', 'Rechnung wurde bezahlt.', {
        ledger = ledger
    }, nil, auditId)
end

math.randomseed(os.time())

exports('createPrivateAccount', createPrivateAccount)
exports('account.createPrivate', createPrivateAccount)
exports('listAccounts', listAccounts)
exports('account.list', listAccounts)
exports('getAccountTransactions', getAccountTransactions)
exports('account.getTransactions', getAccountTransactions)
exports('transferMoney', transferMoney)
exports('account.transfer', transferMoney)
exports('addMoney', addMoney)
exports('account.addMoney', addMoney)
exports('addSystemMoney', addSystemMoney)
exports('account.addSystemMoney', addSystemMoney)
exports('account.removeSystemMoney', removeSystemMoney)
exports('account.executeFuelPurchase', NexaAccountExecuteFuelPurchase)
exports('account.executeImpoundRelease', NexaAccountExecuteImpoundRelease)
exports('account.executePropertyPurchase', NexaAccountExecutePropertyPurchase)
exports('account.propertyPurchase', NexaAccountExecutePropertyPurchase)
exports('createBusinessAccount', createBusinessAccount)
exports('account.createBusiness', createBusinessAccount)
exports('createFactionAccount', createFactionAccount)
exports('account.createFaction', createFactionAccount)
exports('removeMoney', removeMoney)
exports('account.removeMoney', removeMoney)
exports('createMedicalInvoice', createMedicalInvoice)
exports('account.createMedicalInvoice', createMedicalInvoice)
exports('createGovernmentInvoice', createGovernmentInvoice)
exports('account.createGovernmentInvoice', createGovernmentInvoice)
exports('listInvoices', listInvoices)
exports('account.listInvoices', listInvoices)
exports('payInvoice', payInvoice)
exports('account.payInvoice', payInvoice)
