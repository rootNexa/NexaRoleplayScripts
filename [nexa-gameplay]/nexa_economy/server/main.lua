local migrated = false

NexaEconomy = {
    ready = false,
    currencies = {},
    accountTypes = {},
    locks = {}
}

local function response(success, code, message, data, meta)
    return {
        ok = success == true,
        success = success == true,
        code = code or (success and 'OK' or NEXA_ECONOMY_ERRORS.invalidInput),
        message = message or '',
        data = data,
        meta = meta,
        error = success == true and nil or {
            code = code,
            message = message
        }
    }
end

local function ok(data, message, meta)
    return response(true, 'OK', message or 'OK', data, meta)
end

local function fail(code, message, meta)
    return response(false, code, message or code, nil, meta)
end

local function encode(value)
    local encodedOk, encoded = pcall(json.encode, value or {})
    return encodedOk and encoded or '{}'
end

local function decode(value, fallback)
    if type(value) ~= 'string' or value == '' then
        return fallback
    end

    local decodedOk, decoded = pcall(json.decode, value)
    return decodedOk and decoded or fallback
end

local function getCore()
    if GetResourceState('nexa-core') ~= 'started' then
        return nil
    end

    local coreOk, core = pcall(function()
        return exports['nexa-core']:GetCoreObject()
    end)

    return coreOk and core or nil
end

local function log(level, category, message, context)
    local core = getCore()

    if core and core.Logger and core.Logger[level] then
        core.Logger[level](category, message, context)
        return
    end

    print(('[%s] [%s] %s %s'):format(NEXA_ECONOMY.resourceName, level, message, encode(context)))
end

local function emit(eventName, payload)
    local core = getCore()

    if core and core.EventBus then
        core.EventBus.Emit(eventName, payload, {
            resource = NEXA_ECONOMY.resourceName
        })
    end
end

local function normalizeId(value)
    local id = tonumber(value)
    return id and id > 0 and id % 1 == 0 and math.floor(id) or nil
end

local function normalizeString(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    local normalized = value:gsub('^%s+', ''):gsub('%s+$', '')

    if normalized == '' or (maxLength and #normalized > maxLength) then
        return nil
    end

    return normalized
end

local function normalizeSlug(value, maxLength)
    value = normalizeString(value, maxLength or 96)

    if not value then
        return nil
    end

    value = value:lower()

    if value:find('^[a-z0-9_%-:]+$') == nil then
        return nil
    end

    return value
end

local function normalizeAmount(value)
    value = tonumber(value)

    if not value or value < 1 or value % 1 ~= 0 or value > NexaEconomyConfig.maxAmount then
        return nil
    end

    return math.floor(value)
end

local function normalizeRow(row)
    if type(row) ~= 'table' then
        return row
    end

    row.id = normalizeId(row.id)
    row.balance = tonumber(row.balance) or 0
    row.reserved_balance = tonumber(row.reserved_balance) or 0
    row.available_balance = row.balance - row.reserved_balance
    row.metadata = decode(row.metadata_json, {})
    return row
end

local function correlationId(prefix)
    return ('%s:%s:%s:%s'):format(prefix or 'eco', os.time(), GetGameTimer and GetGameTimer() or 0, math.random(100000, 999999))
end

local function normalizeContext(context, action)
    context = type(context) == 'table' and context or {}
    return {
        action = action,
        actor_source = tonumber(context.actor_source or context.source),
        actor_character_id = normalizeId(context.actor_character_id or context.character_id),
        reason = normalizeString(context.reason, 255),
        correlation_id = normalizeString(context.correlation_id, 128) or correlationId(action),
        source_resource = normalizeString(context.source_resource or GetInvokingResource() or NEXA_ECONOMY.resourceName, 64),
        idempotency_key = normalizeString(context.idempotency_key, 128)
    }
end

local function audit(action, context, result, payload)
    context = normalizeContext(context, action)
    payload = payload or {}
    NexaEconomyDatabase.InsertAudit({
        action = action,
        actor_source = context.actor_source,
        actor_character_id = context.actor_character_id,
        account_id = payload.account_id,
        amount = payload.amount,
        result = result.ok and 'success' or 'failed',
        error_code = result.ok and nil or result.code,
        reason = context.reason,
        metadata = payload.metadata,
        correlation_id = context.correlation_id
    })
end

local function withLocks(accountIds, action, fn)
    table.sort(accountIds)

    for _, accountId in ipairs(accountIds) do
        if NexaEconomy.locks[accountId] then
            return fail(NEXA_ECONOMY_ERRORS.invalidInput, 'Account is busy.')
        end
    end

    for _, accountId in ipairs(accountIds) do
        NexaEconomy.locks[accountId] = action
    end

    local okCall, result = pcall(fn)

    for _, accountId in ipairs(accountIds) do
        NexaEconomy.locks[accountId] = nil
    end

    if not okCall then
        log('Error', 'economy.lock', 'Locked operation failed.', { action = action, error = tostring(result) })
        return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Economy operation failed.')
    end

    return result
end

local function ensureCurrency(currency, expectedType)
    currency = normalizeSlug(currency or NexaEconomyConfig.defaultCurrency, 32)
    local definition = currency and NexaEconomy.currencies[currency]

    if not definition or (expectedType and definition.currency_type ~= expectedType) then
        return nil, fail(NEXA_ECONOMY_ERRORS.invalidCurrency, 'Currency is invalid.')
    end

    return currency, nil
end

local function ensureAccountType(accountType)
    accountType = normalizeSlug(accountType, 32)

    if not accountType or not NexaEconomy.accountTypes[accountType] then
        return nil, fail(NEXA_ECONOMY_ERRORS.invalidAccountType, 'Account type is invalid.')
    end

    return accountType, nil
end

local function getAccountRow(account)
    local accountId = normalizeId(account)

    if accountId then
        local row, err = NexaEconomyDatabase.GetAccount(accountId)
        if err then
            return nil, fail(NEXA_ECONOMY_ERRORS.databaseError, 'Account could not be loaded.', err)
        end
        row = normalizeRow(row)
        return row, row and nil or fail(NEXA_ECONOMY_ERRORS.accountNotFound, 'Account not found.')
    end

    local accountKey = normalizeSlug(account, 96)
    if accountKey then
        local row, err = NexaEconomyDatabase.GetAccountByKey(accountKey)
        if err then
            return nil, fail(NEXA_ECONOMY_ERRORS.databaseError, 'Account could not be loaded.', err)
        end
        row = normalizeRow(row)
        return row, row and nil or fail(NEXA_ECONOMY_ERRORS.accountNotFound, 'Account not found.')
    end

    return nil, fail(NEXA_ECONOMY_ERRORS.invalidInput, 'Account reference is invalid.')
end

local function requireActiveAccount(account)
    if account.status ~= NEXA_ECONOMY_ACCOUNT_STATUS.active then
        return fail(NEXA_ECONOMY_ERRORS.accountDisabled, 'Account is not active.')
    end

    return nil
end

local function makeAccountKey(ownerType, ownerId, accountType, currency)
    return ('%s:%s:%s:%s'):format(ownerType, ownerId, accountType, currency)
end

local function insertLedger(transactionId, account, entryType, amount, beforeBalance, afterBalance, beforeReserved, afterReserved, context, category)
    return NexaEconomyDatabase.InsertLedger({
        transaction_id = transactionId,
        account_id = account.id,
        entry_type = entryType,
        amount = amount,
        balance_before = beforeBalance,
        balance_after = afterBalance,
        reserved_before = beforeReserved,
        reserved_after = afterReserved,
        currency = account.currency,
        category = category,
        reason = context.reason,
        correlation_id = context.correlation_id
    })
end

local function recordTransaction(payload, context)
    local transactionId, err = NexaEconomyDatabase.InsertTransaction({
        transaction_key = correlationId('tx'),
        transaction_type = payload.transaction_type,
        status = NEXA_ECONOMY_TRANSACTION_STATUS.pending,
        source_account_id = payload.source_account_id,
        target_account_id = payload.target_account_id,
        amount = payload.amount,
        currency = payload.currency or NexaEconomyConfig.defaultCurrency,
        idempotency_key = context.idempotency_key,
        reason = context.reason,
        metadata = payload.metadata,
        correlation_id = context.correlation_id
    })

    if err then
        return nil, fail(NEXA_ECONOMY_ERRORS.databaseError, 'Transaction could not be created.', err)
    end

    return transactionId, nil
end

local function replayIdempotency(context)
    if not context.idempotency_key then
        return nil
    end

    local row, err = NexaEconomyDatabase.GetTransactionByIdempotency(context.idempotency_key)

    if err then
        return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Idempotency check failed.', err)
    end

    if row then
        return ok(row, 'Idempotent transaction replayed.', { idempotent = true })
    end

    return nil
end

local function completeTransaction(transactionId, status, errorCode)
    NexaEconomyDatabase.UpdateTransactionStatus(transactionId, status, errorCode)
end

local function mutateSingle(account, transactionType, entryType, amount, context, metadata)
    local replay = replayIdempotency(context)
    if replay then
        return replay
    end

    return withLocks({ account.id }, transactionType, function()
        local fresh, invalid = getAccountRow(account.id)
        if invalid then
            return invalid
        end

        invalid = requireActiveAccount(fresh)
        if invalid then
            return invalid
        end

        if entryType == 'debit' and fresh.available_balance < amount then
            return fail(NEXA_ECONOMY_ERRORS.insufficientFunds, 'Insufficient funds.')
        end

        local beforeBalance = fresh.balance
        local beforeReserved = fresh.reserved_balance
        local afterBalance = entryType == 'credit' and beforeBalance + amount or beforeBalance - amount

        local transactionId, txErr = recordTransaction({
            transaction_type = transactionType,
            source_account_id = entryType == 'debit' and fresh.id or nil,
            target_account_id = entryType == 'credit' and fresh.id or nil,
            amount = amount,
            currency = fresh.currency,
            metadata = metadata
        }, context)

        if txErr then
            return txErr
        end

        local queries = {
            {
                query = 'UPDATE nexa_economy_accounts SET balance = ?, reserved_balance = ? WHERE id = ?',
                params = { afterBalance, beforeReserved, fresh.id }
            },
            {
                query = [[
                    INSERT INTO nexa_economy_ledger
                        (transaction_id, account_id, entry_type, amount, balance_before, balance_after, reserved_before,
                         reserved_after, currency, category, reason, correlation_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ]],
                params = {
                    transactionId, fresh.id, entryType, amount, beforeBalance, afterBalance, beforeReserved, beforeReserved,
                    fresh.currency, transactionType, context.reason, context.correlation_id
                }
            },
            {
                query = 'UPDATE nexa_economy_transactions SET status = ? WHERE id = ?',
                params = { NEXA_ECONOMY_TRANSACTION_STATUS.completed, transactionId }
            }
        }

        local _, dbErr = NexaEconomyDatabase.Transaction(queries, { category = 'economy.transaction.single' })

        if dbErr then
            completeTransaction(transactionId, NEXA_ECONOMY_TRANSACTION_STATUS.failed, NEXA_ECONOMY_ERRORS.databaseError)
            return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Transaction failed.', dbErr)
        end

        local result = ok({
            transaction_id = transactionId,
            account_id = fresh.id,
            amount = amount,
            balance_before = beforeBalance,
            balance_after = afterBalance
        }, 'Transaction completed.')
        audit(transactionType, context, result, { account_id = fresh.id, amount = amount, metadata = metadata })
        emit('nexa:internal:economy:transaction_completed', result.data)
        return result
    end)
end

local function registerDefaultCurrencies()
    NexaEconomy.currencies[NEXA_ECONOMY_CURRENCIES.bank] = {
        name = NEXA_ECONOMY_CURRENCIES.bank,
        label = 'Bank',
        currency_type = NEXA_ECONOMY_CURRENCY_TYPES.account
    }
    NexaEconomy.currencies[NEXA_ECONOMY_CURRENCIES.cash] = {
        name = NEXA_ECONOMY_CURRENCIES.cash,
        label = 'Cash',
        currency_type = NEXA_ECONOMY_CURRENCY_TYPES.item,
        item_name = NexaEconomyConfig.cashItem
    }
    NexaEconomy.currencies[NEXA_ECONOMY_CURRENCIES.dirtyCash] = {
        name = NEXA_ECONOMY_CURRENCIES.dirtyCash,
        label = 'Dirty Cash',
        currency_type = NEXA_ECONOMY_CURRENCY_TYPES.item,
        item_name = NexaEconomyConfig.dirtyCashItem
    }
end

local function registerDefaultAccountTypes()
    for _, accountType in pairs(NEXA_ECONOMY_ACCOUNT_TYPES) do
        NexaEconomy.accountTypes[accountType] = true
    end
end

local function ensureCurrencyItem(itemName, label, itemType)
    if GetResourceState('nexa_items') ~= 'started' then
        return
    end

    local existsOk, existing = pcall(function()
        return exports.nexa_items:GetItemDefinition(itemName)
    end)

    if existsOk and existing and existing.ok and existing.data then
        return
    end

    pcall(function()
        exports.nexa_items:CreateItem({
            name = itemName,
            label = label,
            description = label,
            item_type = itemType or 'currency',
            stackable = true,
            max_stack = NexaEconomyConfig.maxAmount,
            usable = false,
            droppable = true,
            tradeable = true,
            enabled = true,
            reason = 'Ensure economy currency item',
            source_resource = NEXA_ECONOMY.resourceName
        })
    end)
end

local function ensureCurrencyItems()
    ensureCurrencyItem(NexaEconomyConfig.cashItem, 'Cash', 'currency')
    ensureCurrencyItem(NexaEconomyConfig.dirtyCashItem, 'Dirty Cash', 'currency')
end

local function getActiveCharacterIdForSource(source)
    source = tonumber(source)

    if not source or source <= 0 then
        return nil
    end

    if GetResourceState('nexa_playerstate') == 'started' then
        local okState, stateResult = pcall(function()
            return exports.nexa_playerstate:GetActiveCharacter(source)
        end)

        if okState and stateResult then
            local data = type(stateResult) == 'table' and (stateResult.data or stateResult) or nil
            local character = data and (data.character or data)
            local characterId = normalizeId(character and (character.id or character.character_id))

            if characterId then
                return characterId
            end
        end
    end

    if GetResourceState('nexa_characters') == 'started' then
        local okCharacter, characterResult = pcall(function()
            return exports.nexa_characters:GetActiveCharacter(source)
        end)

        if okCharacter and characterResult then
            local data = type(characterResult) == 'table' and (characterResult.data or characterResult) or nil
            local character = data and (data.character or data)
            local characterId = normalizeId(character and (character.id or character.character_id))

            if characterId then
                return characterId
            end
        end
    end

    local core = getCore()
    if core and core.Characters and core.Characters.GetActive then
        local character = core.Characters.GetActive(source)
        return normalizeId(character and (character.id or character.character_id))
    end

    return nil
end

function GetAccount(account)
    local row, invalid = getAccountRow(account)
    if invalid then
        return invalid
    end
    return ok(row, 'Account loaded.')
end

function GetCharacterBankAccount(characterIdOrSource)
    local characterId = normalizeId(characterIdOrSource)

    if not characterId then
        return fail(NEXA_ECONOMY_ERRORS.invalidInput, 'Character id is invalid.')
    end

    local ownerId = tostring(characterId)
    local accountType = NexaEconomyConfig.defaultCharacterAccountType
    local currency = NexaEconomyConfig.defaultCurrency
    local row, err = NexaEconomyDatabase.GetAccountByOwner('character', ownerId, accountType)

    if err then
        return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Character account could not be loaded.', err)
    end

    row = normalizeRow(row)

    if row then
        return ok(row, 'Character bank account loaded.')
    end

    local accountKey = makeAccountKey('character', ownerId, accountType, currency)
    local accountId
    accountId, err = NexaEconomyDatabase.InsertAccount({
        account_key = accountKey,
        owner_type = 'character',
        owner_id = ownerId,
        account_type = accountType,
        currency = currency,
        label = ('Character %s Bank'):format(ownerId),
        status = NEXA_ECONOMY_ACCOUNT_STATUS.active,
        metadata = {}
    })

    if err then
        return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Character account could not be created.', err)
    end

    row = normalizeRow(NexaEconomyDatabase.GetAccount(accountId))
    return ok(row, 'Character bank account created.')
end

function GetBalance(account)
    local result = GetAccount(account)
    if not result.ok then
        return result
    end
    return ok({ balance = result.data.balance, currency = result.data.currency }, 'Balance loaded.')
end

function GetAvailableBalance(account)
    local result = GetAccount(account)
    if not result.ok then
        return result
    end
    return ok({ available_balance = result.data.available_balance, currency = result.data.currency }, 'Available balance loaded.')
end

function GetReservedBalance(account)
    local result = GetAccount(account)
    if not result.ok then
        return result
    end
    return ok({ reserved_balance = result.data.reserved_balance, currency = result.data.currency }, 'Reserved balance loaded.')
end

function GetLedger(account, limit)
    local row, invalid = getAccountRow(account)
    if invalid then
        return invalid
    end

    local rows, err = NexaEconomyDatabase.GetLedger(row.id, tonumber(limit) or 100)
    if err then
        return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Ledger could not be loaded.', err)
    end
    return ok(rows or {}, 'Ledger loaded.')
end

function GetTransaction(id)
    id = normalizeId(id)
    if not id then
        return fail(NEXA_ECONOMY_ERRORS.invalidInput, 'Transaction id is invalid.')
    end

    local row, err = NexaEconomyDatabase.GetTransaction(id)
    if err then
        return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Transaction could not be loaded.', err)
    end
    return row and ok(row, 'Transaction loaded.') or fail(NEXA_ECONOMY_ERRORS.invalidInput, 'Transaction not found.')
end

function CanAfford(account, amount)
    amount = normalizeAmount(amount)
    if not amount then
        return fail(NEXA_ECONOMY_ERRORS.invalidAmount, 'Amount is invalid.')
    end

    local available = GetAvailableBalance(account)
    if not available.ok then
        return available
    end
    return ok(available.data.available_balance >= amount, 'Affordability checked.', available.data)
end

function Credit(account, amount, context)
    amount = normalizeAmount(amount)
    if not amount then
        return fail(NEXA_ECONOMY_ERRORS.invalidAmount, 'Amount is invalid.')
    end

    context = normalizeContext(context, NEXA_ECONOMY_TRANSACTION_TYPES.credit)
    local row, invalid = getAccountRow(account)
    if invalid then
        return invalid
    end
    return mutateSingle(row, NEXA_ECONOMY_TRANSACTION_TYPES.credit, 'credit', amount, context, {})
end

function Debit(account, amount, context)
    amount = normalizeAmount(amount)
    if not amount then
        return fail(NEXA_ECONOMY_ERRORS.invalidAmount, 'Amount is invalid.')
    end

    context = normalizeContext(context, NEXA_ECONOMY_TRANSACTION_TYPES.debit)
    local row, invalid = getAccountRow(account)
    if invalid then
        return invalid
    end
    return mutateSingle(row, NEXA_ECONOMY_TRANSACTION_TYPES.debit, 'debit', amount, context, {})
end

function Transfer(sourceAccount, targetAccount, amount, context)
    amount = normalizeAmount(amount)
    if not amount then
        return fail(NEXA_ECONOMY_ERRORS.invalidAmount, 'Amount is invalid.')
    end

    context = normalizeContext(context, NEXA_ECONOMY_TRANSACTION_TYPES.transfer)
    local replay = replayIdempotency(context)
    if replay then
        return replay
    end

    local sourceRow, invalid = getAccountRow(sourceAccount)
    if invalid then
        return invalid
    end
    local targetRow
    targetRow, invalid = getAccountRow(targetAccount)
    if invalid then
        return invalid
    end

    if sourceRow.id == targetRow.id then
        return fail(NEXA_ECONOMY_ERRORS.invalidInput, 'Transfer accounts must differ.')
    end

    return withLocks({ sourceRow.id, targetRow.id }, 'transfer', function()
        sourceRow = normalizeRow(NexaEconomyDatabase.GetAccount(sourceRow.id))
        targetRow = normalizeRow(NexaEconomyDatabase.GetAccount(targetRow.id))

        invalid = requireActiveAccount(sourceRow) or requireActiveAccount(targetRow)
        if invalid then
            return invalid
        end

        if sourceRow.available_balance < amount then
            return fail(NEXA_ECONOMY_ERRORS.insufficientFunds, 'Insufficient funds.')
        end

        local transactionId, txErr = recordTransaction({
            transaction_type = NEXA_ECONOMY_TRANSACTION_TYPES.transfer,
            source_account_id = sourceRow.id,
            target_account_id = targetRow.id,
            amount = amount,
            currency = sourceRow.currency
        }, context)

        if txErr then
            return txErr
        end

        local sourceAfter = sourceRow.balance - amount
        local targetAfter = targetRow.balance + amount
        local queries = {
            { query = 'UPDATE nexa_economy_accounts SET balance = ? WHERE id = ?', params = { sourceAfter, sourceRow.id } },
            { query = 'UPDATE nexa_economy_accounts SET balance = ? WHERE id = ?', params = { targetAfter, targetRow.id } },
            {
                query = [[INSERT INTO nexa_economy_ledger
                    (transaction_id, account_id, entry_type, amount, balance_before, balance_after, reserved_before, reserved_after, currency, category, reason, correlation_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
                params = { transactionId, sourceRow.id, 'debit', amount, sourceRow.balance, sourceAfter, sourceRow.reserved_balance, sourceRow.reserved_balance, sourceRow.currency, 'transfer', context.reason, context.correlation_id }
            },
            {
                query = [[INSERT INTO nexa_economy_ledger
                    (transaction_id, account_id, entry_type, amount, balance_before, balance_after, reserved_before, reserved_after, currency, category, reason, correlation_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
                params = { transactionId, targetRow.id, 'credit', amount, targetRow.balance, targetAfter, targetRow.reserved_balance, targetRow.reserved_balance, targetRow.currency, 'transfer', context.reason, context.correlation_id }
            },
            { query = 'UPDATE nexa_economy_transactions SET status = ? WHERE id = ?', params = { NEXA_ECONOMY_TRANSACTION_STATUS.completed, transactionId } }
        }

        local _, dbErr = NexaEconomyDatabase.Transaction(queries, { category = 'economy.transaction.transfer' })
        if dbErr then
            completeTransaction(transactionId, NEXA_ECONOMY_TRANSACTION_STATUS.failed, NEXA_ECONOMY_ERRORS.databaseError)
            return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Transfer failed.', dbErr)
        end

        local result = ok({ transaction_id = transactionId, source_account_id = sourceRow.id, target_account_id = targetRow.id, amount = amount }, 'Transfer completed.')
        audit('transfer', context, result, { account_id = sourceRow.id, amount = amount, metadata = { target_account_id = targetRow.id } })
        emit('nexa:internal:economy:transfer_completed', result.data)
        return result
    end)
end

function Reserve(account, amount, context)
    amount = normalizeAmount(amount)
    if not amount then
        return fail(NEXA_ECONOMY_ERRORS.invalidAmount, 'Amount is invalid.')
    end

    context = normalizeContext(context, 'reserve')
    local row, invalid = getAccountRow(account)
    if invalid then
        return invalid
    end

    return withLocks({ row.id }, 'reserve', function()
        local fresh = normalizeRow(NexaEconomyDatabase.GetAccount(row.id))
        if fresh.available_balance < amount then
            return fail(NEXA_ECONOMY_ERRORS.insufficientFunds, 'Insufficient funds.')
        end

        local beforeReserved = fresh.reserved_balance
        local afterReserved = beforeReserved + amount
        local transactionId, txErr = recordTransaction({
            transaction_type = NEXA_ECONOMY_TRANSACTION_TYPES.reservation,
            source_account_id = fresh.id,
            amount = amount,
            currency = fresh.currency
        }, context)
        if txErr then
            return txErr
        end

        local reservationId, reservationErr = NexaEconomyDatabase.InsertReservation({
            reservation_key = correlationId('res'),
            account_id = fresh.id,
            amount = amount,
            currency = fresh.currency,
            status = NEXA_ECONOMY_RESERVATION_STATUS.active,
            reason = context.reason,
            expires_at = os.time() + NexaEconomyConfig.defaultReservationTtlSeconds,
            metadata = {},
            correlation_id = context.correlation_id
        })
        if reservationErr then
            completeTransaction(transactionId, NEXA_ECONOMY_TRANSACTION_STATUS.failed, NEXA_ECONOMY_ERRORS.databaseError)
            return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Reservation could not be created.', reservationErr)
        end

        local queries = {
            { query = 'UPDATE nexa_economy_accounts SET reserved_balance = ? WHERE id = ?', params = { afterReserved, fresh.id } },
            {
                query = [[INSERT INTO nexa_economy_ledger
                    (transaction_id, account_id, entry_type, amount, balance_before, balance_after, reserved_before, reserved_after, currency, category, reason, correlation_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
                params = { transactionId, fresh.id, 'reserve', amount, fresh.balance, fresh.balance, beforeReserved, afterReserved, fresh.currency, 'reservation', context.reason, context.correlation_id }
            },
            { query = 'UPDATE nexa_economy_transactions SET status = ? WHERE id = ?', params = { NEXA_ECONOMY_TRANSACTION_STATUS.completed, transactionId } }
        }
        local _, dbErr = NexaEconomyDatabase.Transaction(queries, { category = 'economy.reservation.create' })
        if dbErr then
            return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Reservation failed.', dbErr)
        end

        return ok({ reservation_id = reservationId, transaction_id = transactionId, account_id = fresh.id, amount = amount }, 'Reservation created.')
    end)
end

function CaptureReservation(reservationId, context)
    reservationId = normalizeId(reservationId)
    if not reservationId then
        return fail(NEXA_ECONOMY_ERRORS.invalidInput, 'Reservation id is invalid.')
    end

    context = normalizeContext(context, 'capture_reservation')
    local reservation, err = NexaEconomyDatabase.GetReservation(reservationId)
    if err then
        return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Reservation could not be loaded.', err)
    end
    if not reservation then
        return fail(NEXA_ECONOMY_ERRORS.reservationNotFound, 'Reservation not found.')
    end
    if reservation.status ~= NEXA_ECONOMY_RESERVATION_STATUS.active then
        return fail(NEXA_ECONOMY_ERRORS.reservationInvalidState, 'Reservation is not active.')
    end

    local account = normalizeRow(NexaEconomyDatabase.GetAccount(reservation.account_id))
    return withLocks({ account.id }, 'capture_reservation', function()
        local beforeBalance = account.balance
        local beforeReserved = account.reserved_balance
        local afterBalance = beforeBalance - tonumber(reservation.amount)
        local afterReserved = beforeReserved - tonumber(reservation.amount)
        local transactionId, txErr = recordTransaction({
            transaction_type = NEXA_ECONOMY_TRANSACTION_TYPES.reservationCapture,
            source_account_id = account.id,
            amount = tonumber(reservation.amount),
            currency = account.currency
        }, context)
        if txErr then
            return txErr
        end
        local queries = {
            { query = 'UPDATE nexa_economy_accounts SET balance = ?, reserved_balance = ? WHERE id = ?', params = { afterBalance, afterReserved, account.id } },
            { query = 'UPDATE nexa_economy_reservations SET status = ?, captured_transaction_id = ? WHERE id = ?', params = { NEXA_ECONOMY_RESERVATION_STATUS.captured, transactionId, reservationId } },
            {
                query = [[INSERT INTO nexa_economy_ledger
                    (transaction_id, account_id, entry_type, amount, balance_before, balance_after, reserved_before, reserved_after, currency, category, reason, correlation_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
                params = { transactionId, account.id, 'reservation_capture', tonumber(reservation.amount), beforeBalance, afterBalance, beforeReserved, afterReserved, account.currency, 'reservation_capture', context.reason, context.correlation_id }
            },
            { query = 'UPDATE nexa_economy_transactions SET status = ? WHERE id = ?', params = { NEXA_ECONOMY_TRANSACTION_STATUS.completed, transactionId } }
        }
        local _, dbErr = NexaEconomyDatabase.Transaction(queries, { category = 'economy.reservation.capture' })
        if dbErr then
            return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Reservation capture failed.', dbErr)
        end
        return ok({ reservation_id = reservationId, transaction_id = transactionId }, 'Reservation captured.')
    end)
end

function ReleaseReservation(reservationId, context)
    reservationId = normalizeId(reservationId)
    if not reservationId then
        return fail(NEXA_ECONOMY_ERRORS.invalidInput, 'Reservation id is invalid.')
    end

    context = normalizeContext(context, 'release_reservation')
    local reservation, err = NexaEconomyDatabase.GetReservation(reservationId)
    if err then
        return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Reservation could not be loaded.', err)
    end
    if not reservation then
        return fail(NEXA_ECONOMY_ERRORS.reservationNotFound, 'Reservation not found.')
    end
    if reservation.status ~= NEXA_ECONOMY_RESERVATION_STATUS.active then
        return fail(NEXA_ECONOMY_ERRORS.reservationInvalidState, 'Reservation is not active.')
    end

    local account = normalizeRow(NexaEconomyDatabase.GetAccount(reservation.account_id))
    return withLocks({ account.id }, 'release_reservation', function()
        local beforeReserved = account.reserved_balance
        local afterReserved = beforeReserved - tonumber(reservation.amount)
        local transactionId, txErr = recordTransaction({
            transaction_type = NEXA_ECONOMY_TRANSACTION_TYPES.reservationRelease,
            source_account_id = account.id,
            amount = tonumber(reservation.amount),
            currency = account.currency
        }, context)
        if txErr then
            return txErr
        end
        local queries = {
            { query = 'UPDATE nexa_economy_accounts SET reserved_balance = ? WHERE id = ?', params = { afterReserved, account.id } },
            { query = 'UPDATE nexa_economy_reservations SET status = ?, released_transaction_id = ? WHERE id = ?', params = { NEXA_ECONOMY_RESERVATION_STATUS.released, transactionId, reservationId } },
            {
                query = [[INSERT INTO nexa_economy_ledger
                    (transaction_id, account_id, entry_type, amount, balance_before, balance_after, reserved_before, reserved_after, currency, category, reason, correlation_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
                params = { transactionId, account.id, 'reservation_release', tonumber(reservation.amount), account.balance, account.balance, beforeReserved, afterReserved, account.currency, 'reservation_release', context.reason, context.correlation_id }
            },
            { query = 'UPDATE nexa_economy_transactions SET status = ? WHERE id = ?', params = { NEXA_ECONOMY_TRANSACTION_STATUS.completed, transactionId } }
        }
        local _, dbErr = NexaEconomyDatabase.Transaction(queries, { category = 'economy.reservation.release' })
        if dbErr then
            return fail(NEXA_ECONOMY_ERRORS.databaseError, 'Reservation release failed.', dbErr)
        end
        return ok({ reservation_id = reservationId, transaction_id = transactionId }, 'Reservation released.')
    end)
end

local function getCharacterInventory(characterId)
    if GetResourceState('nexa_inventory') ~= 'started' then
        return nil, fail(NEXA_ECONOMY_ERRORS.dependencyMissing, 'Inventory is not started.')
    end

    local inventory = exports.nexa_inventory:GetCharacterInventory(characterId)
    if not inventory or not inventory.ok then
        return nil, fail(NEXA_ECONOMY_ERRORS.inventoryError, 'Character inventory could not be loaded.', inventory)
    end

    return inventory.data, nil
end

local function getInventoryItemAmount(inventoryId, itemName)
    local hasResponse = exports.nexa_inventory:HasItem(inventoryId, itemName, 1)
    if not hasResponse or not hasResponse.ok then
        return 0, hasResponse
    end
    return hasResponse.meta and tonumber(hasResponse.meta.amount) or 0, nil
end

local function addInventoryCurrency(characterId, itemName, amount, context)
    local inventory, invalid = getCharacterInventory(characterId)
    if invalid then
        return invalid
    end
    return exports.nexa_inventory:AddItem(inventory.id, itemName, amount, {}, {
        reason = context.reason or 'Economy currency add',
        source_resource = NEXA_ECONOMY.resourceName,
        correlation_id = context.correlation_id
    })
end

local function removeInventoryCurrency(characterId, itemName, amount, context)
    local inventory, invalid = getCharacterInventory(characterId)
    if invalid then
        return invalid
    end

    local itemsResponse = exports.nexa_inventory:GetItems(inventory.id)
    if not itemsResponse or not itemsResponse.ok then
        return fail(NEXA_ECONOMY_ERRORS.inventoryError, 'Inventory items could not be loaded.', itemsResponse)
    end

    local remaining = amount
    for _, item in ipairs(itemsResponse.data or {}) do
        if item.item_name == itemName and remaining > 0 then
            local take = math.min(remaining, tonumber(item.amount) or 0)
            local removed = exports.nexa_inventory:RemoveItem(inventory.id, item.id, take, {
                reason = context.reason or 'Economy currency remove',
                source_resource = NEXA_ECONOMY.resourceName,
                correlation_id = context.correlation_id
            })
            if not removed or not removed.ok then
                return fail(NEXA_ECONOMY_ERRORS.inventoryError, 'Currency item could not be removed.', removed)
            end
            remaining = remaining - take
        end
    end

    if remaining > 0 then
        return fail(NEXA_ECONOMY_ERRORS.insufficientFunds, 'Not enough currency items.')
    end

    return ok({ character_id = characterId, item_name = itemName, amount = amount }, 'Currency item removed.')
end

function GetCash(characterId)
    local inventory, invalid = getCharacterInventory(characterId)
    if invalid then
        return invalid
    end
    local amount = getInventoryItemAmount(inventory.id, NexaEconomyConfig.cashItem)
    return ok({ character_id = characterId, amount = amount, item_name = NexaEconomyConfig.cashItem }, 'Cash loaded.')
end

function GetDirtyCash(characterId)
    local inventory, invalid = getCharacterInventory(characterId)
    if invalid then
        return invalid
    end
    local amount = getInventoryItemAmount(inventory.id, NexaEconomyConfig.dirtyCashItem)
    return ok({ character_id = characterId, amount = amount, item_name = NexaEconomyConfig.dirtyCashItem }, 'Dirty cash loaded.')
end

function AddCash(characterId, amount, context)
    amount = normalizeAmount(amount)
    if not amount then
        return fail(NEXA_ECONOMY_ERRORS.invalidAmount, 'Amount is invalid.')
    end
    return addInventoryCurrency(characterId, NexaEconomyConfig.cashItem, amount, normalizeContext(context, 'add_cash'))
end

function RemoveCash(characterId, amount, context)
    amount = normalizeAmount(amount)
    if not amount then
        return fail(NEXA_ECONOMY_ERRORS.invalidAmount, 'Amount is invalid.')
    end
    return removeInventoryCurrency(characterId, NexaEconomyConfig.cashItem, amount, normalizeContext(context, 'remove_cash'))
end

function AddDirtyCash(characterId, amount, context)
    amount = normalizeAmount(amount)
    if not amount then
        return fail(NEXA_ECONOMY_ERRORS.invalidAmount, 'Amount is invalid.')
    end
    return addInventoryCurrency(characterId, NexaEconomyConfig.dirtyCashItem, amount, normalizeContext(context, 'add_dirty_cash'))
end

function RemoveDirtyCash(characterId, amount, context)
    amount = normalizeAmount(amount)
    if not amount then
        return fail(NEXA_ECONOMY_ERRORS.invalidAmount, 'Amount is invalid.')
    end
    return removeInventoryCurrency(characterId, NexaEconomyConfig.dirtyCashItem, amount, normalizeContext(context, 'remove_dirty_cash'))
end

local function createSaga(sagaType, context, metadata)
    local sagaId = NexaEconomyDatabase.InsertSaga({
        saga_key = correlationId('saga'),
        saga_type = sagaType,
        status = NEXA_ECONOMY_SAGA_STATUS.started,
        source = context.source_resource,
        metadata = metadata,
        correlation_id = context.correlation_id
    })
    return sagaId
end

local function sagaStep(sagaId, stepName, status, metadata, errorCode)
    if not sagaId then
        return
    end
    NexaEconomyDatabase.InsertSagaStep({
        saga_id = sagaId,
        step_name = stepName,
        status = status,
        metadata = metadata,
        error_code = errorCode
    })
end

function DepositCash(characterId, amount, context)
    amount = normalizeAmount(amount)
    if not amount then
        return fail(NEXA_ECONOMY_ERRORS.invalidAmount, 'Amount is invalid.')
    end

    context = normalizeContext(context, NEXA_ECONOMY_TRANSACTION_TYPES.depositCash)
    local sagaId = createSaga('deposit_cash', context, { character_id = characterId, amount = amount })
    local removed = RemoveCash(characterId, amount, context)
    sagaStep(sagaId, 'inventory_remove_cash', removed.ok and 'completed' or 'failed', removed.data, removed.code)
    if not removed.ok then
        NexaEconomyDatabase.UpdateSagaStatus(sagaId, NEXA_ECONOMY_SAGA_STATUS.failed, removed.code)
        return removed
    end

    local account = GetCharacterBankAccount(characterId)
    if not account.ok then
        AddCash(characterId, amount, context)
        sagaStep(sagaId, 'compensate_cash', 'completed', { amount = amount }, account.code)
        NexaEconomyDatabase.UpdateSagaStatus(sagaId, NEXA_ECONOMY_SAGA_STATUS.compensated, account.code)
        return account
    end

    local credited = mutateSingle(account.data, NEXA_ECONOMY_TRANSACTION_TYPES.depositCash, 'credit', amount, context, { saga_id = sagaId })
    sagaStep(sagaId, 'bank_credit', credited.ok and 'completed' or 'failed', credited.data, credited.code)
    if not credited.ok then
        AddCash(characterId, amount, context)
        sagaStep(sagaId, 'compensate_cash', 'completed', { amount = amount }, credited.code)
        NexaEconomyDatabase.UpdateSagaStatus(sagaId, NEXA_ECONOMY_SAGA_STATUS.compensated, credited.code)
        return credited
    end

    NexaEconomyDatabase.UpdateSagaStatus(sagaId, NEXA_ECONOMY_SAGA_STATUS.completed)
    return ok({ saga_id = sagaId, transaction = credited.data, amount = amount }, 'Cash deposited.')
end

function WithdrawCash(characterId, amount, context)
    amount = normalizeAmount(amount)
    if not amount then
        return fail(NEXA_ECONOMY_ERRORS.invalidAmount, 'Amount is invalid.')
    end

    context = normalizeContext(context, NEXA_ECONOMY_TRANSACTION_TYPES.withdrawCash)
    local sagaId = createSaga('withdraw_cash', context, { character_id = characterId, amount = amount })
    local account = GetCharacterBankAccount(characterId)
    if not account.ok then
        NexaEconomyDatabase.UpdateSagaStatus(sagaId, NEXA_ECONOMY_SAGA_STATUS.failed, account.code)
        return account
    end

    local debited = mutateSingle(account.data, NEXA_ECONOMY_TRANSACTION_TYPES.withdrawCash, 'debit', amount, context, { saga_id = sagaId })
    sagaStep(sagaId, 'bank_debit', debited.ok and 'completed' or 'failed', debited.data, debited.code)
    if not debited.ok then
        NexaEconomyDatabase.UpdateSagaStatus(sagaId, NEXA_ECONOMY_SAGA_STATUS.failed, debited.code)
        return debited
    end

    local added = AddCash(characterId, amount, context)
    sagaStep(sagaId, 'inventory_add_cash', added.ok and 'completed' or 'failed', added.data, added.code)
    if not added.ok then
        Credit(account.data.id, amount, {
            reason = 'Withdraw compensation',
            correlation_id = context.correlation_id,
            source_resource = NEXA_ECONOMY.resourceName
        })
        sagaStep(sagaId, 'compensate_bank_credit', 'completed', { amount = amount }, added.code)
        NexaEconomyDatabase.UpdateSagaStatus(sagaId, NEXA_ECONOMY_SAGA_STATUS.compensated, added.code)
        return added
    end

    NexaEconomyDatabase.UpdateSagaStatus(sagaId, NEXA_ECONOMY_SAGA_STATUS.completed)
    return ok({ saga_id = sagaId, transaction = debited.data, amount = amount }, 'Cash withdrawn.')
end

local function registerCallbacks()
    local core = getCore()
    if not core or not core.Callbacks then
        return
    end

    core.Callbacks.RegisterNetwork(NEXA_ECONOMY_CALLBACKS.getLedger, function(source, payload)
        payload = type(payload) == 'table' and payload or {}
        local characterId = getActiveCharacterIdForSource(source)

        if not characterId then
            return fail(NEXA_ECONOMY_ERRORS.invalidInput, 'No active character.')
        end

        local account = GetCharacterBankAccount(characterId)

        if not account.ok then
            return account
        end

        return GetLedger(account.data.id, payload.limit)
    end, { rateLimitMs = NexaEconomyConfig.callbacks.rateLimitMs })

    core.Callbacks.RegisterNetwork(NEXA_ECONOMY_CALLBACKS.getOwnBalance, function(source)
        local characterId = getActiveCharacterIdForSource(source)

        if not characterId then
            return fail(NEXA_ECONOMY_ERRORS.invalidInput, 'No active character.')
        end

        local account = GetCharacterBankAccount(characterId)

        if not account.ok then
            return account
        end

        return GetBalance(account.data.id)
    end, { rateLimitMs = NexaEconomyConfig.callbacks.rateLimitMs })

    core.Callbacks.RegisterNetwork(NEXA_ECONOMY_CALLBACKS.transfer, function(source, payload)
        payload = type(payload) == 'table' and payload or {}
        local characterId = getActiveCharacterIdForSource(source)

        if not characterId then
            return fail(NEXA_ECONOMY_ERRORS.invalidInput, 'No active character.')
        end

        local sourceAccount = GetCharacterBankAccount(characterId)

        if not sourceAccount.ok then
            return sourceAccount
        end

        return Transfer(sourceAccount.data.id, payload.target_account_id, payload.amount, {
            source = source,
            reason = payload.reason,
            idempotency_key = payload.idempotency_key
        })
    end, { rateLimitMs = NexaEconomyConfig.callbacks.rateLimitMs })

    core.Callbacks.RegisterNetwork(NEXA_ECONOMY_CALLBACKS.depositCash, function(source, payload)
        payload = type(payload) == 'table' and payload or {}
        local characterId = getActiveCharacterIdForSource(source)

        if not characterId then
            return fail(NEXA_ECONOMY_ERRORS.invalidInput, 'No active character.')
        end

        return DepositCash(characterId, payload.amount, { source = source, reason = payload.reason, idempotency_key = payload.idempotency_key })
    end, { rateLimitMs = NexaEconomyConfig.callbacks.rateLimitMs })

    core.Callbacks.RegisterNetwork(NEXA_ECONOMY_CALLBACKS.withdrawCash, function(source, payload)
        payload = type(payload) == 'table' and payload or {}
        local characterId = getActiveCharacterIdForSource(source)

        if not characterId then
            return fail(NEXA_ECONOMY_ERRORS.invalidInput, 'No active character.')
        end

        return WithdrawCash(characterId, payload.amount, { source = source, reason = payload.reason, idempotency_key = payload.idempotency_key })
    end, { rateLimitMs = NexaEconomyConfig.callbacks.rateLimitMs })
end

AddEventHandler('nexa:playerstate:active', function(payload)
    payload = type(payload) == 'table' and payload or {}
    local characterId = normalizeId(payload.character_id)

    if characterId then
        GetCharacterBankAccount(characterId)
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    registerDefaultCurrencies()
    registerDefaultAccountTypes()

    if NexaEconomyConfig.autoMigrate then
        local migrateOk, migrateErr = NexaEconomyDatabase.Migrate()
        migrated = migrateOk == true

        if not migrated then
            log('Error', 'economy.migration', 'Economy migrations failed.', { error = migrateErr })
        end
    end

    ensureCurrencyItems()
    registerCallbacks()
    NexaEconomy.ready = migrated
    log('Info', 'economy.start', 'nexa_economy started.', { migrated = migrated })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    NexaEconomy.ready = false
    NexaEconomy.locks = {}
    log('Info', 'economy.stop', 'nexa_economy stopped.')
end)

exports('GetAccount', GetAccount)
exports('GetCharacterBankAccount', GetCharacterBankAccount)
exports('GetBalance', GetBalance)
exports('GetAvailableBalance', GetAvailableBalance)
exports('GetReservedBalance', GetReservedBalance)
exports('GetLedger', GetLedger)
exports('GetTransaction', GetTransaction)
exports('GetCash', GetCash)
exports('GetDirtyCash', GetDirtyCash)
exports('CanAfford', CanAfford)
exports('Credit', Credit)
exports('Debit', Debit)
exports('Transfer', Transfer)
exports('Reserve', Reserve)
exports('CaptureReservation', CaptureReservation)
exports('ReleaseReservation', ReleaseReservation)
exports('DepositCash', DepositCash)
exports('WithdrawCash', WithdrawCash)
exports('AddCash', AddCash)
exports('RemoveCash', RemoveCash)
exports('AddDirtyCash', AddDirtyCash)
exports('RemoveDirtyCash', RemoveDirtyCash)
exports('getStatus', function()
    return { resourceName = NEXA_ECONOMY.resourceName, version = NEXA_ECONOMY.version, ready = NexaEconomy.ready, migrated = migrated }
end)
exports('getSchema', NexaEconomyDatabase.GetSchema)
