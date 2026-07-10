NexaCharacters = NexaCharacters or {}
NexaCharacters.activeBySource = NexaCharacters.activeBySource or {}
NexaCharacters.activeSourceByCharacterId = NexaCharacters.activeSourceByCharacterId or {}
NexaCharacters.selectionLocks = NexaCharacters.selectionLocks or {}

local CORE_RESOURCE = 'nexa-core'
local IDENTITY_RESOURCE = 'nexa_identity'

local function getCore()
    if GetResourceState(CORE_RESOURCE) ~= 'started' then
        return nil
    end

    local ok, coreObject = pcall(function()
        return exports[CORE_RESOURCE]:GetCoreObject()
    end)

    return ok and type(coreObject) == 'table' and coreObject or nil
end

local function log(level, category, message, context)
    local coreObject = getCore()

    if coreObject and coreObject.Logger and coreObject.Logger[level] then
        coreObject.Logger[level](category, message, context)
        return
    end

    print(('[%s] [%s] %s %s'):format(NEXA_CHARACTERS.resourceName, level:lower(), message, json.encode(context or {})))
end

local function emitInternal(eventName, payload)
    local coreObject = getCore()

    if coreObject and coreObject.EventBus then
        coreObject.EventBus.Emit(eventName, payload, {
            module = NEXA_CHARACTERS.resourceName
        })
    end
end

local function response(success, code, message, data, meta)
    return {
        success = success == true,
        code = code or (success and 'OK' or 'INTERNAL_ERROR'),
        message = message or '',
        data = data,
        meta = meta
    }
end

local function decodeJson(value)
    if type(value) ~= 'string' or value == '' then
        return {}
    end

    local ok, decoded = pcall(json.decode, value)
    return ok and type(decoded) == 'table' and decoded or {}
end

local function trim(value)
    if type(value) ~= 'string' then
        return nil
    end

    return value:match('^%s*(.-)%s*$')
end

local function mapCharacter(row)
    if type(row) ~= 'table' then
        return nil
    end

    return {
        id = tonumber(row.id),
        accountId = tonumber(row.account_id),
        legacyPlayerId = tonumber(row.player_id),
        slot = tonumber(row.slot),
        status = row.status,
        firstName = row.first_name,
        lastName = row.last_name,
        birthdate = row.birthdate,
        gender = row.gender,
        height = tonumber(row.height),
        weight = tonumber(row.weight),
        nationality = row.nationality,
        backstory = row.backstory,
        phoneNumber = row.phone_number,
        metadata = decodeJson(row.metadata),
        version = tonumber(row.version),
        lastSelectedAt = row.last_selected_at,
        createdAt = row.created_at,
        updatedAt = row.updated_at,
        deletedAt = row.deleted_at
    }
end

local function getAccountIdForSource(source)
    source = tonumber(source)

    if not source or source <= 0 or GetResourceState(IDENTITY_RESOURCE) ~= 'started' then
        return nil, NEXA_CHARACTERS.errors.accountNotReady
    end

    local ok, accountId, err = pcall(function()
        return exports[IDENTITY_RESOURCE]:GetAccountId(source)
    end)

    if not ok then
        return nil, NEXA_CHARACTERS.errors.accountNotReady
    end

    return tonumber(accountId), err
end

local function hasPermission(source, permission)
    local ok, allowed = pcall(function()
        return exports[CORE_RESOURCE]:HasPermission(source, permission)
    end)

    return ok and allowed == true
end

local function validateName(value)
    value = trim(value)

    if not value or #value < NEXA_CHARACTERS_CONFIG.minNameLength or #value > NEXA_CHARACTERS_CONFIG.maxNameLength then
        return nil, NEXA_CHARACTERS.errors.invalidName
    end

    if not value:match("^[%a%s%-']+$") then
        return nil, NEXA_CHARACTERS.errors.invalidName
    end

    return value, nil
end

local function validateBirthdate(value)
    value = trim(value)

    if not value or not value:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return nil, NEXA_CHARACTERS.errors.invalidBirthdate
    end

    local year = tonumber(value:sub(1, 4))
    local month = tonumber(value:sub(6, 7))
    local day = tonumber(value:sub(9, 10))

    if not year or year < NEXA_CHARACTERS_CONFIG.minBirthYear or year > NEXA_CHARACTERS_CONFIG.maxBirthYear then
        return nil, NEXA_CHARACTERS.errors.invalidBirthdate
    end

    if not month or month < 1 or month > 12 or not day or day < 1 or day > 31 then
        return nil, NEXA_CHARACTERS.errors.invalidBirthdate
    end

    return value, nil
end

local function validateNumber(value, minValue, maxValue, errorCode)
    value = tonumber(value)

    if not value or value < minValue or value > maxValue then
        return nil, errorCode
    end

    return math.floor(value), nil
end

function NexaCharacters.ValidateCreate(payload)
    if type(payload) ~= 'table' then
        return nil, NEXA_CHARACTERS.errors.invalidInput
    end

    for field in pairs(NEXA_CHARACTERS_CONFIG.protectedUpdateFields) do
        if payload[field] ~= nil then
            return nil, NEXA_CHARACTERS.errors.updateForbidden
        end
    end

    local firstName, firstNameErr = validateName(payload.firstName or payload.first_name)
    local lastName, lastNameErr = validateName(payload.lastName or payload.last_name)
    local birthdate, birthdateErr = validateBirthdate(payload.birthdate)
    local height, heightErr = validateNumber(payload.height, NEXA_CHARACTERS_CONFIG.minHeight, NEXA_CHARACTERS_CONFIG.maxHeight, NEXA_CHARACTERS.errors.invalidHeight)
    local weight, weightErr = validateNumber(payload.weight, NEXA_CHARACTERS_CONFIG.minWeight, NEXA_CHARACTERS_CONFIG.maxWeight, NEXA_CHARACTERS.errors.invalidWeight)
    local gender = trim(payload.gender or 'unknown') or 'unknown'

    if firstNameErr or lastNameErr or birthdateErr or heightErr or weightErr then
        return nil, firstNameErr or lastNameErr or birthdateErr or heightErr or weightErr
    end

    if not NEXA_CHARACTERS_CONFIG.allowedGenders[gender] then
        return nil, NEXA_CHARACTERS.errors.invalidInput
    end

    local slot = tonumber(payload.slot)

    if slot ~= nil and (slot < 1 or slot > NEXA_CHARACTERS_CONFIG.futureMaxCharacters) then
        return nil, NEXA_CHARACTERS.errors.invalidInput
    end

    return {
        firstName = firstName,
        lastName = lastName,
        birthdate = birthdate,
        gender = gender,
        height = height,
        weight = weight,
        slot = slot,
        nationality = trim(payload.nationality),
        backstory = trim(payload.backstory),
        phoneNumber = trim(payload.phoneNumber or payload.phone_number),
        metadata = type(payload.metadata) == 'table' and payload.metadata or {}
    }, nil
end

function NexaCharacters.ValidateUpdate(changes, actor)
    if type(changes) ~= 'table' then
        return nil, NEXA_CHARACTERS.errors.invalidInput
    end

    for field in pairs(NEXA_CHARACTERS_CONFIG.protectedUpdateFields) do
        if changes[field] ~= nil then
            return nil, NEXA_CHARACTERS.errors.updateForbidden
        end
    end

    local payload = {}

    if changes.firstName ~= nil or changes.first_name ~= nil then
        local value, err = validateName(changes.firstName or changes.first_name)

        if err then
            return nil, err
        end

        payload.firstName = value
    end

    if changes.lastName ~= nil or changes.last_name ~= nil then
        local value, err = validateName(changes.lastName or changes.last_name)

        if err then
            return nil, err
        end

        payload.lastName = value
    end

    if changes.birthdate ~= nil then
        local value, err = validateBirthdate(changes.birthdate)

        if err then
            return nil, err
        end

        payload.birthdate = value
    end

    if changes.height ~= nil then
        local value, err = validateNumber(changes.height, NEXA_CHARACTERS_CONFIG.minHeight, NEXA_CHARACTERS_CONFIG.maxHeight, NEXA_CHARACTERS.errors.invalidHeight)

        if err then
            return nil, err
        end

        payload.height = value
    end

    if changes.weight ~= nil then
        local value, err = validateNumber(changes.weight, NEXA_CHARACTERS_CONFIG.minWeight, NEXA_CHARACTERS_CONFIG.maxWeight, NEXA_CHARACTERS.errors.invalidWeight)

        if err then
            return nil, err
        end

        payload.weight = value
    end

    if changes.gender ~= nil then
        local gender = trim(changes.gender)

        if not gender or not NEXA_CHARACTERS_CONFIG.allowedGenders[gender] then
            return nil, NEXA_CHARACTERS.errors.invalidInput
        end

        payload.gender = gender
    end

    if changes.nationality ~= nil then
        payload.nationality = trim(changes.nationality)
    end

    if changes.backstory ~= nil then
        payload.backstory = trim(changes.backstory)
    end

    if changes.phoneNumber ~= nil or changes.phone_number ~= nil then
        payload.phoneNumber = trim(changes.phoneNumber or changes.phone_number)
    end

    if changes.metadata ~= nil then
        if type(changes.metadata) ~= 'table' then
            return nil, NEXA_CHARACTERS.errors.invalidInput
        end

        payload.metadata = changes.metadata
    end

    if actor and actor.admin == true and changes.status ~= nil then
        payload.status = changes.status
    end

    if next(payload) == nil then
        return nil, NEXA_CHARACTERS.errors.invalidInput
    end

    return payload, nil
end

local function nextSlot(characters)
    local used = {}

    for _, character in ipairs(characters or {}) do
        if character.slot then
            used[character.slot] = true
        end
    end

    for slot = 1, NEXA_CHARACTERS_CONFIG.maxCharacters do
        if not used[slot] then
            return slot
        end
    end

    return nil
end

function NexaCharacters.ListForAccount(accountId)
    local rows, err = NexaCharacters.Database.ListForAccount(accountId)

    if err then
        return nil, err
    end

    local characters = {}

    for _, row in ipairs(rows or {}) do
        characters[#characters + 1] = mapCharacter(row)
    end

    return characters, nil
end

function NexaCharacters.Create(accountId, payload, actor)
    accountId = tonumber(accountId)

    if not accountId then
        return nil, NEXA_CHARACTERS.errors.accountNotReady
    end

    local validated, validationErr = NexaCharacters.ValidateCreate(payload)

    if not validated then
        return nil, validationErr
    end

    local accountStorage, accountErr = NexaCharacters.Database.GetAccountStorage(accountId)

    if accountErr or not accountStorage or not accountStorage.legacy_player_id then
        return nil, NEXA_CHARACTERS.errors.accountNotReady
    end

    local characters, listErr = NexaCharacters.ListForAccount(accountId)

    if listErr then
        return nil, listErr
    end

    if #characters >= NEXA_CHARACTERS_CONFIG.maxCharacters then
        return nil, NEXA_CHARACTERS.errors.limitReached
    end

    validated.slot = validated.slot or nextSlot(characters)

    if not validated.slot then
        return nil, NEXA_CHARACTERS.errors.limitReached
    end

    local existingSlot, slotErr = NexaCharacters.Database.FindSlot(accountId, validated.slot)

    if slotErr then
        return nil, slotErr
    end

    if existingSlot then
        return nil, NEXA_CHARACTERS.errors.slotOccupied
    end

    local characterId, createErr = NexaCharacters.Database.Insert(accountId, tonumber(accountStorage.legacy_player_id), validated)

    if not characterId then
        return nil, createErr
    end

    log('Audit', 'characters.create', 'Character erstellt.', {
        accountId = accountId,
        characterId = characterId,
        actor = actor
    })

    return NexaCharacters.GetById(characterId), nil
end

function NexaCharacters.GetById(characterId)
    characterId = tonumber(characterId)

    if not characterId then
        return nil, NEXA_CHARACTERS.errors.invalidInput
    end

    local row, err = NexaCharacters.Database.GetById(characterId)

    if err then
        return nil, err
    end

    if not row then
        return nil, NEXA_CHARACTERS.errors.notFound
    end

    return mapCharacter(row), nil
end

function NexaCharacters.GetBySource(source)
    return NexaCharacters.activeBySource[tonumber(source)], nil
end

function NexaCharacters.Select(source, characterId)
    source = tonumber(source)
    characterId = tonumber(characterId)

    if not source or not characterId then
        return nil, NEXA_CHARACTERS.errors.invalidInput
    end

    if NexaCharacters.selectionLocks[source] then
        return nil, NEXA_CHARACTERS.errors.selectionInProgress
    end

    local accountId, accountErr = getAccountIdForSource(source)

    if not accountId then
        return nil, accountErr
    end

    local character, err = NexaCharacters.GetById(characterId)

    if err then
        return nil, err
    end

    if character.accountId ~= accountId then
        log('Security', 'characters.select', 'Fremde Character-Auswahl blockiert.', {
            source = source,
            accountId = accountId,
            characterId = characterId
        })
        return nil, NEXA_CHARACTERS.errors.notOwned
    end

    if character.status == NEXA_CHARACTERS.statuses.deleted or character.deletedAt ~= nil then
        return nil, NEXA_CHARACTERS.errors.deleted
    end

    if character.status == NEXA_CHARACTERS.statuses.blocked then
        return nil, NEXA_CHARACTERS.errors.blocked
    end

    local activeSource = NexaCharacters.activeSourceByCharacterId[characterId]

    if activeSource and activeSource ~= source then
        return nil, NEXA_CHARACTERS.errors.alreadyActive
    end

    NexaCharacters.selectionLocks[source] = true

    local previous = NexaCharacters.activeBySource[source]

    if previous then
        NexaCharacters.activeSourceByCharacterId[previous.id] = nil
    end

    NexaCharacters.Database.MarkSelected(characterId)
    NexaCharacters.activeBySource[source] = character
    NexaCharacters.activeSourceByCharacterId[characterId] = source
    NexaCharacters.selectionLocks[source] = nil

    emitInternal(NEXA_CHARACTERS.events.selected, {
        source = source,
        accountId = accountId,
        character = character
    })

    return character, nil
end

function NexaCharacters.Update(characterId, changes, actor)
    local character, err = NexaCharacters.GetById(characterId)

    if err then
        return nil, err
    end

    local updatePayload, validationErr = NexaCharacters.ValidateUpdate(changes, actor)

    if not updatePayload then
        return nil, validationErr
    end

    local ok, updateErr = NexaCharacters.Database.Update(character.id, updatePayload)

    if not ok then
        return nil, updateErr
    end

    local updated = NexaCharacters.GetById(character.id)
    local source = NexaCharacters.activeSourceByCharacterId[character.id]

    if source then
        NexaCharacters.activeBySource[source] = updated
    end

    return updated, nil
end

function NexaCharacters.Delete(characterId, actor, reason)
    local character, err = NexaCharacters.GetById(characterId)

    if err then
        return nil, err
    end

    if actor and actor.source and not hasPermission(actor.source, 'nexa.character.delete') then
        return nil, NEXA_CHARACTERS.errors.deleteForbidden
    end

    local ok, deleteErr = NexaCharacters.Database.SoftDelete(character.id, reason or 'deleted')

    if not ok then
        return nil, deleteErr
    end

    local source = NexaCharacters.activeSourceByCharacterId[character.id]

    if source then
        NexaCharacters.Release(source, 'character_deleted')
    end

    emitInternal(NEXA_CHARACTERS.events.deleted, {
        characterId = character.id,
        accountId = character.accountId,
        reason = reason
    })

    return true, nil
end

function NexaCharacters.Release(source, reason)
    source = tonumber(source)
    local character = NexaCharacters.activeBySource[source]

    if character then
        NexaCharacters.activeSourceByCharacterId[character.id] = nil
    end

    NexaCharacters.activeBySource[source] = nil
    NexaCharacters.selectionLocks[source] = nil

    emitInternal(NEXA_CHARACTERS.events.released, {
        source = source,
        characterId = character and character.id or nil,
        reason = reason
    })

    return true, nil
end

function NexaCharacters.IsActive(source)
    return NexaCharacters.activeBySource[tonumber(source)] ~= nil
end

local function exportResult(data, err)
    if err then
        return response(false, err, 'Character operation failed.')
    end

    return response(true, 'OK', 'OK', data)
end

local function callbackResult(exportResponse)
    if type(exportResponse) ~= 'table' then
        return {
            ok = false,
            error = {
                code = 'INTERNAL_ERROR',
                message = 'Character operation failed.'
            }
        }
    end

    if exportResponse.success == true then
        return {
            ok = true,
            data = exportResponse.data
        }
    end

    return {
        ok = false,
        error = {
            code = exportResponse.code or 'INTERNAL_ERROR',
            message = exportResponse.message or 'Character operation failed.'
        }
    }
end

function ListCharacters(source)
    local accountId, err = getAccountIdForSource(source)

    if not accountId then
        return exportResult(nil, err)
    end

    local characters, listErr = NexaCharacters.ListForAccount(accountId)
    return exportResult({
        characters = characters or {}
    }, listErr)
end

function GetCharacter(characterId)
    local character, err = NexaCharacters.GetById(characterId)
    return exportResult({
        character = character
    }, err)
end

function GetActiveCharacter(source)
    local character = NexaCharacters.GetBySource(source)
    return exportResult({
        character = character
    }, nil)
end

function CreateCharacter(source, payload)
    local accountId, err = getAccountIdForSource(source)

    if not accountId then
        return exportResult(nil, err)
    end

    local character, createErr = NexaCharacters.Create(accountId, payload, {
        source = tonumber(source)
    })

    return exportResult({
        character = character
    }, createErr)
end

function SelectCharacter(source, characterId)
    local character, err = NexaCharacters.Select(source, characterId)
    return exportResult({
        character = character
    }, err)
end

function UpdateCharacter(source, characterId, changes)
    if not hasPermission(source, 'nexa.character.update') then
        return exportResult(nil, NEXA_CHARACTERS.errors.updateForbidden)
    end

    local character, err = NexaCharacters.Update(characterId, changes, {
        source = tonumber(source),
        admin = true
    })

    return exportResult({
        character = character
    }, err)
end

function DeleteCharacter(source, characterId, reason)
    local ok, err = NexaCharacters.Delete(characterId, {
        source = tonumber(source)
    }, reason)

    return exportResult({
        deleted = ok == true
    }, err)
end

function BlockCharacter(source, characterId, reason)
    if not hasPermission(source, 'nexa.character.block') then
        return exportResult(nil, NEXA_CHARACTERS.errors.updateForbidden)
    end

    local character, err = NexaCharacters.Update(characterId, {
        status = NEXA_CHARACTERS.statuses.blocked,
        metadata = {
            blockReason = reason
        }
    }, {
        source = tonumber(source),
        admin = true
    })

    return exportResult({
        character = character
    }, err)
end

function RestoreCharacter(source, characterId)
    if not hasPermission(source, 'nexa.character.restore') then
        return exportResult(nil, NEXA_CHARACTERS.errors.updateForbidden)
    end

    local character, err = NexaCharacters.Update(characterId, {
        status = NEXA_CHARACTERS.statuses.active
    }, {
        source = tonumber(source),
        admin = true
    })

    return exportResult({
        character = character
    }, err)
end

exports('ListCharacters', ListCharacters)
exports('GetCharacter', GetCharacter)
exports('GetActiveCharacter', GetActiveCharacter)
exports('CreateCharacter', CreateCharacter)
exports('SelectCharacter', SelectCharacter)
exports('UpdateCharacter', UpdateCharacter)
exports('DeleteCharacter', DeleteCharacter)
exports('BlockCharacter', BlockCharacter)
exports('RestoreCharacter', RestoreCharacter)

local function registerCallbacks()
    local coreObject = getCore()

    if not coreObject or not coreObject.Callbacks then
        return
    end

    coreObject.Callbacks.RegisterNetwork(NEXA_CHARACTERS.callbacks.list, function(source)
        return callbackResult(ListCharacters(source))
    end, {
        rateLimitMs = 1000
    })

    coreObject.Callbacks.RegisterNetwork(NEXA_CHARACTERS.callbacks.create, function(source, payload)
        return callbackResult(CreateCharacter(source, payload))
    end, {
        rateLimitMs = 2500,
        validate = function(payload)
            return type(payload) == 'table'
        end
    })

    coreObject.Callbacks.RegisterNetwork(NEXA_CHARACTERS.callbacks.select, function(source, payload)
        return callbackResult(SelectCharacter(source, payload and payload.characterId))
    end, {
        rateLimitMs = 1000,
        validate = function(payload)
            return type(payload) == 'table' and tonumber(payload.characterId) ~= nil
        end
    })

    coreObject.Callbacks.RegisterNetwork(NEXA_CHARACTERS.callbacks.identityStatus, function(source)
        return {
            ok = true,
            data = {
                ready = exports[IDENTITY_RESOURCE]:IsAccountReady(source),
                accountId = select(1, exports[IDENTITY_RESOURCE]:GetAccountId(source))
            }
        }
    end, {
        rateLimitMs = 1000
    })
end

AddEventHandler('playerDropped', function(reason)
    NexaCharacters.Release(source, reason)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    local migrationsOk, migrationErr = NexaCharacters.Database.RegisterMigrations()

    if not migrationsOk then
        log('Error', 'characters.start', 'Character-Migrationen fehlgeschlagen.', {
            error = migrationErr
        })
        return
    end

    registerCallbacks()
    log('Info', 'characters.start', 'nexa_characters gestartet.', {
        version = NEXA_CHARACTERS.version
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    NexaCharacters.activeBySource = {}
    NexaCharacters.activeSourceByCharacterId = {}
    NexaCharacters.selectionLocks = {}
end)
