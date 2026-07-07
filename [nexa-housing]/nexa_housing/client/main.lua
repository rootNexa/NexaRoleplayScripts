local function notify(response)
    if lib and lib.notify then
        lib.notify({
            title = NexaHousingLocale.title,
            description = type(response) == 'table' and response.message or NexaHousingLocale.denied,
            type = type(response) == 'table' and response.success == true and 'success' or 'error'
        })
    end
end

local function getProperties(payload)
    return lib.callback.await(NexaHousingConfig.callbacks.list, false, payload or {})
end

local function getAccessibleProperties(payload)
    return lib.callback.await(NexaHousingConfig.callbacks.accessible, false, payload or {})
end

local function getStatus(propertyUnitId)
    return lib.callback.await(NexaHousingConfig.callbacks.status, false, {
        propertyUnitId = propertyUnitId
    })
end

local function hasAccess(propertyUnitId)
    return lib.callback.await(NexaHousingConfig.callbacks.access, false, {
        propertyUnitId = propertyUnitId
    })
end

local function purchaseProperty(propertyUnitId, accountReference)
    accountReference = type(accountReference) == 'table' and accountReference or {}

    local response = lib.callback.await(NexaHousingConfig.callbacks.purchase, false, {
        propertyUnitId = propertyUnitId,
        accountId = accountReference.accountId,
        accountNumber = accountReference.accountNumber
    })

    notify(response)
    return response
end

local function rentProperty(propertyUnitId, accountReference)
    accountReference = type(accountReference) == 'table' and accountReference or {}

    local response = lib.callback.await(NexaHousingConfig.callbacks.rent, false, {
        propertyUnitId = propertyUnitId,
        accountId = accountReference.accountId,
        accountNumber = accountReference.accountNumber
    })

    notify(response)
    return response
end

local function grantAccess(propertyUnitId, characterId, accessType, options)
    options = type(options) == 'table' and options or {}

    local response = lib.callback.await(NexaHousingConfig.callbacks.grantAccess, false, {
        propertyUnitId = propertyUnitId,
        characterId = characterId,
        accessType = accessType or 'guest',
        durationMinutes = options.durationMinutes,
        expiresAt = options.expiresAt
    })

    notify(response)
    return response
end

local function listAccess(propertyUnitId)
    return lib.callback.await(NexaHousingConfig.callbacks.listAccess, false, {
        propertyUnitId = propertyUnitId
    })
end

local function revokeAccess(propertyUnitId, characterId, reason)
    local response = lib.callback.await(NexaHousingConfig.callbacks.revokeAccess, false, {
        propertyUnitId = propertyUnitId,
        characterId = characterId,
        reason = reason
    })

    notify(response)
    return response
end

local function ensureStorage(propertyUnitId, storageType)
    return lib.callback.await(NexaHousingConfig.callbacks.ensureStorage, false, {
        propertyUnitId = propertyUnitId,
        storageType = storageType or 'private'
    })
end

local function openStorage(propertyUnitId, storageType)
    local response = lib.callback.await(NexaHousingConfig.callbacks.openStorage, false, {
        propertyUnitId = propertyUnitId,
        storageType = storageType or 'private'
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify(response)
        return response
    end

    notify({
        success = true,
        message = NexaHousingLocale.storageOpened
    })

    return response
end

CreateThread(function()
    if NexaHousingClientConfig.enableCommand then
        RegisterCommand(NexaHousingClientConfig.commandName, function()
            getProperties({
                limit = 25
            })
        end, false)
    end
end)

exports('getProperties', getProperties)
exports('getAccessibleProperties', getAccessibleProperties)
exports('getStatus', getStatus)
exports('hasAccess', hasAccess)
exports('purchaseProperty', purchaseProperty)
exports('rentProperty', rentProperty)
exports('grantAccess', grantAccess)
exports('listAccess', listAccess)
exports('revokeAccess', revokeAccess)
exports('ensureStorage', ensureStorage)
exports('openStorage', openStorage)
