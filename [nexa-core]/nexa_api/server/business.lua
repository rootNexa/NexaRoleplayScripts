local businessLimits = {
    maxNameLength = 64,
    maxCodeLength = 32,
    maxLabelLength = 64,
    maxTransactionLimit = 50,
    maxAmount = 100000000
}

local businessRolePermissions = {
    owner = {
        view = true,
        manage_members = true,
        manage_accounts = true,
        transfer = true
    },
    manager = {
        view = true,
        manage_members = true,
        transfer = true
    },
    accountant = {
        view = true,
        transfer = true
    },
    employee = {
        view = true
    }
}

local function respond(success, code, message, data, meta, auditId)
    return NexaApiResponse(success, code, message, data, meta, auditId)
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

    if number == nil or number < 1 or number > businessLimits.maxAmount then
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

local function getActor(source)
    local active = getActiveCharacter(source)

    if active == nil or not active.success or active.data == nil or active.data.character == nil then
        return nil, 'CHARACTER_NOT_LOADED'
    end

    return active.data.character, 'OK'
end

local function hasGlobalPermission(source, permission)
    if GetResourceState('nexa_permissions') ~= 'started' then
        return false
    end

    local result = exports.nexa_permissions:has(source, permission)

    return result ~= nil and result.success == true
end

local function writeBusinessAudit(action, actor, targetType, targetId, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return nil
    end

    local result = exports.nexa_audit:write({
        eventType = 'business',
        severity = 'info',
        actorPlayerId = actor and actor.player_id or nil,
        actorCharacterId = actor and actor.id or nil,
        targetType = targetType,
        targetId = targetId,
        action = action,
        resourceName = 'nexa_api',
        metadata = metadata or {}
    })

    return result and result.audit_id or nil
end

local function createBusinessCode(name)
    local base = name:upper():gsub('[^A-Z0-9]', ''):sub(1, 12)

    if base == '' then
        base = 'BUSINESS'
    end

    return ('%s%s%03d'):format(base, os.date('%y%m%d'), math.random(0, 999))
end

local function generateBusinessCode(name)
    for _ = 1, 10 do
        local code = createBusinessCode(name)
        local existing = MySQL.scalar.await('SELECT id FROM businesses WHERE business_code = ? LIMIT 1', {
            code
        })

        if existing == nil then
            return code
        end
    end

    return nil
end

local function getBusiness(businessId)
    return MySQL.single.await([[
        SELECT id, business_code, name, label, status, metadata, created_at
        FROM businesses
        WHERE id = ?
        LIMIT 1
    ]], {
        businessId
    })
end

local function getActiveMember(businessId, characterId)
    return MySQL.single.await([[
        SELECT id, business_id, character_id, role_name, joined_at
        FROM business_members
        WHERE business_id = ? AND character_id = ? AND left_at IS NULL
        LIMIT 1
    ]], {
        businessId,
        characterId
    })
end

local function hasBusinessPermission(characterId, businessId, permission)
    local member = getActiveMember(businessId, characterId)

    if member == nil then
        return false, nil
    end

    local rolePermissions = businessRolePermissions[member.role_name] or {}

    return rolePermissions[permission] == true, member
end

local function getBusinessAccount(businessId, accountRole)
    return MySQL.single.await([[
        SELECT ba.id, ba.business_id, ba.account_id, ba.account_role, ba.is_active,
            a.account_number, a.balance, a.is_frozen
        FROM business_accounts ba
        JOIN accounts a ON a.id = ba.account_id
        WHERE ba.business_id = ? AND ba.account_role = ? AND ba.is_active = TRUE
        LIMIT 1
    ]], {
        businessId,
        accountRole
    })
end

local function insertBusinessTransaction(entry)
    return MySQL.insert.await([[
        INSERT INTO business_transactions (
            transaction_number, business_id, business_account_id, ledger_id,
            actor_character_id, transaction_type, amount, label, metadata, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        entry.transactionNumber,
        entry.businessId,
        entry.businessAccountId,
        entry.ledgerId,
        entry.actorCharacterId,
        entry.transactionType,
        entry.amount,
        entry.label,
        encodeMetadata(entry.metadata)
    })
end

local function createTransactionNumber(ledgerId)
    return ('BTX%s'):format(ledgerId)
end

local function beginBusinessTransaction()
    MySQL.query.await('START TRANSACTION')
end

local function commitBusinessTransaction()
    MySQL.query.await('COMMIT')
end

local function rollbackBusinessTransaction()
    MySQL.query.await('ROLLBACK')
end

function createBusiness(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if not hasGlobalPermission(source, 'business.create') then
        return respond(false, 'NO_PERMISSION', 'Du darfst keine Firma erstellen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local name = normalizeText(payload.name, nil)
    local label = normalizeText(payload.label, name)

    if name == nil or label == nil or #name > businessLimits.maxNameLength or #label > businessLimits.maxLabelLength then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Firmendaten.', nil, nil, nil)
    end

    local businessCode = normalizeText(payload.businessCode, nil)

    if businessCode ~= nil and #businessCode > businessLimits.maxCodeLength then
        return respond(false, 'INVALID_INPUT', 'Ungueltiger Firmencode.', nil, nil, nil)
    end

    businessCode = businessCode or generateBusinessCode(name)

    if businessCode == nil then
        return respond(false, 'CONFLICT', 'Firmencode konnte nicht erzeugt werden.', nil, nil, nil)
    end

    beginBusinessTransaction()

    local success, businessId = pcall(function()
        local createdBusinessId = MySQL.insert.await([[
            INSERT INTO businesses (business_code, name, label, status, metadata, created_at)
            VALUES (?, ?, ?, 'active', ?, NOW())
        ]], {
            businessCode,
            name,
            label,
            encodeMetadata(payload.metadata)
        })

        MySQL.insert.await([[
            INSERT INTO business_members (business_id, character_id, role_name, joined_at)
            VALUES (?, ?, 'owner', NOW())
        ]], {
            createdBusinessId,
            actor.id
        })

        return createdBusinessId
    end)

    if not success or businessId == nil then
        rollbackBusinessTransaction()

        return respond(false, 'CONFLICT', 'Firma konnte nicht erstellt werden.', nil, nil, nil)
    end

    commitBusinessTransaction()

    local account = createBusinessAccount(source, {
        businessId = businessId,
        accountRole = 'primary'
    })

    if not account.success then
        MySQL.update.await("UPDATE businesses SET status = 'closed' WHERE id = ?", {
            businessId
        })

        return account
    end

    local auditId = writeBusinessAudit('business.create', actor, 'business', businessId, {
        businessCode = businessCode,
        accountId = account.data and account.data.account and account.data.account.id or nil
    })

    return respond(true, 'CREATED', 'Firma wurde erstellt.', {
        business = getBusiness(businessId),
        account = account.data and account.data.account or nil
    }, nil, auditId)
end

function listBusinesses(source)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local rows = MySQL.query.await([[
        SELECT b.id, b.business_code, b.name, b.label, b.status, b.created_at, bm.role_name
        FROM businesses b
        JOIN business_members bm ON bm.business_id = b.id
        WHERE bm.character_id = ? AND bm.left_at IS NULL
        ORDER BY b.label ASC
    ]], {
        actor.id
    })

    return respond(true, 'OK', 'Firmen wurden geladen.', {
        businesses = rows or {}
    }, nil, nil)
end

function addBusinessMember(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local businessId = normalizeId(payload.businessId)
    local characterId = normalizeId(payload.characterId)
    local roleName = normalizeText(payload.roleName, 'employee')

    if businessId == nil or characterId == nil or businessRolePermissions[roleName] == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Mitgliedsdaten.', nil, nil, nil)
    end

    local allowed = hasBusinessPermission(actor.id, businessId, 'manage_members')

    if not allowed and not hasGlobalPermission(source, 'business.manage') then
        return respond(false, 'NO_PERMISSION', 'Du darfst diese Firma nicht verwalten.', nil, nil, nil)
    end

    MySQL.update.await([[
        INSERT INTO business_members (business_id, character_id, role_name, joined_at)
        VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE role_name = VALUES(role_name), left_at = NULL
    ]], {
        businessId,
        characterId,
        roleName
    })

    local auditId = writeBusinessAudit('business.memberAdd', actor, 'business', businessId, {
        characterId = characterId,
        roleName = roleName
    })

    return respond(true, 'OK', 'Mitarbeiter wurde aktualisiert.', nil, nil, auditId)
end

function removeBusinessMember(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local businessId = normalizeId(payload.businessId)
    local characterId = normalizeId(payload.characterId)

    if businessId == nil or characterId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Mitgliedsdaten.', nil, nil, nil)
    end

    local allowed = hasBusinessPermission(actor.id, businessId, 'manage_members')

    if not allowed and not hasGlobalPermission(source, 'business.manage') then
        return respond(false, 'NO_PERMISSION', 'Du darfst diese Firma nicht verwalten.', nil, nil, nil)
    end

    MySQL.update.await([[
        UPDATE business_members
        SET left_at = NOW()
        WHERE business_id = ? AND character_id = ? AND left_at IS NULL
    ]], {
        businessId,
        characterId
    })

    local auditId = writeBusinessAudit('business.memberRemove', actor, 'business', businessId, {
        characterId = characterId
    })

    return respond(true, 'OK', 'Mitarbeiter wurde entfernt.', nil, nil, auditId)
end

function listBusinessAccounts(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local businessId = normalizeId(payload and payload.businessId)

    if businessId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Firmendaten.', nil, nil, nil)
    end

    local allowed = hasBusinessPermission(actor.id, businessId, 'view')

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du hast keinen Zugriff auf diese Firma.', nil, nil, nil)
    end

    local rows = MySQL.query.await([[
        SELECT ba.id, ba.business_id, ba.account_id, ba.account_role, ba.is_active,
            a.account_number, a.balance, a.currency, a.is_frozen
        FROM business_accounts ba
        JOIN accounts a ON a.id = ba.account_id
        WHERE ba.business_id = ? AND ba.is_active = TRUE
        ORDER BY ba.account_role ASC
    ]], {
        businessId
    })

    return respond(true, 'OK', 'Firmenkonten wurden geladen.', {
        accounts = rows or {}
    }, nil, nil)
end

function transferBusinessMoney(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    if type(payload) ~= 'table' then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Anfrage.', nil, nil, nil)
    end

    local businessId = normalizeId(payload.businessId)
    local amount = normalizeAmount(payload.amount)
    local toAccountId = normalizeId(payload.toAccountId)
    local reason = normalizeText(payload.reason, 'Firmentransaktion')
    local accountRole = normalizeText(payload.accountRole, 'primary')

    if businessId == nil or amount == nil or toAccountId == nil or reason == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Transaktionsdaten.', nil, nil, nil)
    end

    local allowed = hasBusinessPermission(actor.id, businessId, 'transfer')

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du darfst keine Firmentransaktion ausfuehren.', nil, nil, nil)
    end

    local businessAccount = getBusinessAccount(businessId, accountRole)

    if businessAccount == nil then
        return respond(false, 'NOT_FOUND', 'Firmenkonto wurde nicht gefunden.', nil, nil, nil)
    end

    local transfer = transferMoney(source, {
        fromAccountId = businessAccount.account_id,
        toAccountId = toAccountId,
        amount = amount,
        reason = reason
    })

    if not transfer.success then
        return transfer
    end

    local ledgerId = transfer.data and transfer.data.ledger and transfer.data.ledger.id or nil
    if ledgerId == nil then
        return respond(false, 'DATABASE_ERROR', 'Firmentransaktion konnte nicht referenziert werden.', nil, nil, nil)
    end

    local businessTransactionOk, businessTransactionId = pcall(function()
        return insertBusinessTransaction({
            transactionNumber = createTransactionNumber(ledgerId),
            businessId = businessId,
            businessAccountId = businessAccount.id,
            ledgerId = ledgerId,
            actorCharacterId = actor.id,
            transactionType = 'transfer',
            amount = amount,
            label = reason,
            metadata = {
                toAccountId = toAccountId
            }
        })
    end)

    if not businessTransactionOk then
        local existingTransactionId = MySQL.scalar.await('SELECT id FROM business_transactions WHERE ledger_id = ? LIMIT 1', {
            ledgerId
        })

        if existingTransactionId == nil then
            return respond(false, 'DATABASE_ERROR', 'Firmentransaktion konnte nicht protokolliert werden.', nil, nil, nil)
        end

        businessTransactionId = existingTransactionId
    end

    local auditId = writeBusinessAudit('business.transfer', actor, 'business', businessId, {
        ledgerId = ledgerId,
        businessTransactionId = businessTransactionId,
        amount = amount
    })

    return respond(true, 'OK', 'Firmentransaktion wurde ausgefuehrt.', {
        ledger = transfer.data and transfer.data.ledger or nil,
        businessTransactionId = businessTransactionId
    }, nil, auditId)
end

function listBusinessTransactions(source, payload)
    local actor, actorCode = getActor(source)

    if actor == nil then
        return respond(false, actorCode, 'Kein aktiver Charakter geladen.', nil, nil, nil)
    end

    local businessId = normalizeId(payload and payload.businessId)

    if businessId == nil then
        return respond(false, 'INVALID_INPUT', 'Ungueltige Firmendaten.', nil, nil, nil)
    end

    local allowed = hasBusinessPermission(actor.id, businessId, 'view')

    if not allowed then
        return respond(false, 'NO_PERMISSION', 'Du hast keinen Zugriff auf diese Firma.', nil, nil, nil)
    end

    local limit = normalizeId(payload and payload.limit) or 25

    if limit > businessLimits.maxTransactionLimit then
        limit = businessLimits.maxTransactionLimit
    end

    local rows = MySQL.query.await([[
        SELECT id, transaction_number, business_id, business_account_id, ledger_id,
            actor_character_id, transaction_type, amount, label, created_at
        FROM business_transactions
        WHERE business_id = ?
        ORDER BY created_at DESC, id DESC
        LIMIT ?
    ]], {
        businessId,
        limit
    })

    return respond(true, 'OK', 'Firmentransaktionen wurden geladen.', {
        transactions = rows or {}
    }, {
        limit = limit
    }, nil)
end

math.randomseed(os.time())

exports('business.create', createBusiness)
exports('business.list', listBusinesses)
exports('business.addMember', addBusinessMember)
exports('business.removeMember', removeBusinessMember)
exports('business.listAccounts', listBusinessAccounts)
exports('business.transfer', transferBusinessMoney)
exports('business.listTransactions', listBusinessTransactions)
