local function notify(response)
    if response == nil then
        return
    end

    lib.notify({
        title = 'Charakterverwaltung',
        description = response.message or 'Der Vorgang konnte nicht abgeschlossen werden.',
        type = response.success and 'success' or 'error'
    })
end

local function debugLog(message, metadata)
    if GetConvar('nexa:identityDebug', 'false') ~= 'true' then
        return
    end

    print(('[nexa_identity] %s %s'):format(message, metadata and json.encode(metadata) or ''))
end

local identitySelectionCompleted = false

local function readNuiState()
    local keepInput = false

    pcall(function()
        keepInput = IsNuiFocusKeepingInput()
    end)

    return {
        keepInput = keepInput,
        openContext = lib.getOpenContextMenu and lib.getOpenContextMenu() or nil
    }
end

local function cleanupIdentityUi(reason)
    debugLog('identity UI cleanup started', {
        reason = reason,
        before = readNuiState()
    })

    pcall(function()
        lib.hideContext(false)
    end)

    pcall(function()
        lib.closeInputDialog()
    end)

    if GetResourceState('nexa_ui') == 'started' then
        pcall(function()
            exports.nexa_ui:close()
        end)
    end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    debugLog('identity UI cleanup completed', {
        reason = reason,
        after = readNuiState()
    })
end

local function debugCallbackWatch(name)
    local pending = true

    CreateThread(function()
        Wait(10000)

        if pending then
            debugLog(('callback timeout warning: %s did not return within 10s'):format(name))
        end
    end)

    return function()
        pending = false
    end
end

local function debugPayloadTypes(payload)
    if GetConvar('nexa:identityDebug', 'false') ~= 'true' then
        return
    end

    local fieldTypes = {}

    for key, value in pairs(payload) do
        fieldTypes[key] = type(value)
    end

    debugLog('createCharacter payload', {
        payload = payload,
        fieldTypes = fieldTypes
    })
end

local function formatCharacterTitle(character)
    return ('%s %s'):format(character.firstname, character.lastname)
end

local function openCreateDialog()
    local input = lib.inputDialog('Charakter erstellen', {
        {
            type = 'input',
            label = 'Vorname',
            required = true,
            min = NexaIdentityConfig.minNameLength,
            max = NexaIdentityConfig.maxNameLength
        },
        {
            type = 'input',
            label = 'Nachname',
            required = true,
            min = NexaIdentityConfig.minNameLength,
            max = NexaIdentityConfig.maxNameLength
        },
        {
            type = 'date',
            label = 'Geburtsdatum',
            required = true,
            format = 'YYYY-MM-DD',
            returnString = true
        },
        {
            type = 'select',
            label = 'Geschlecht',
            required = true,
            options = {
                { value = 'male', label = 'Maennlich' },
                { value = 'female', label = 'Weiblich' },
                { value = 'diverse', label = 'Divers' }
            }
        },
        {
            type = 'input',
            label = 'Herkunft',
            required = false,
            default = NexaIdentityConfig.defaultNationality,
            max = 64
        }
    })

    if input == nil then
        debugLog('createCharacter dialog cancelled')
        return
    end

    local payload = {
        firstname = input[1],
        lastname = input[2],
        birthdate = input[3],
        gender = input[4],
        nationality = input[5] or NexaIdentityConfig.defaultNationality
    }

    debugLog('2 Charakter erstellt')
    debugPayloadTypes(payload)

    local markCreateReturned = debugCallbackWatch('nexa:identity:cb:createCharacter')
    local response = lib.callback.await('nexa:identity:cb:createCharacter', false, payload)
    markCreateReturned()

    debugLog('4 Servercallback erfolgreich: createCharacter returned', {
        success = response and response.success or false,
        code = response and response.code or nil,
        characterId = response and response.data and response.data.character and response.data.character.id or nil
    })
    notify(response)

    if response ~= nil and response.success then
        debugLog('createCharacter success: reopening identity manager for selection', {
            characterId = response.data and response.data.character and response.data.character.id or nil
        })
        TriggerEvent(NEXA_IDENTITY_EVENTS.openManager)
    end
end

local function openCharacterManager()
    if identitySelectionCompleted then
        cleanupIdentityUi('openManager ignored after selectCharacter')
        debugLog('openManager ignored after selectCharacter')
        return
    end

    debugLog('1 Identity UI geoeffnet')

    local markListReturned = debugCallbackWatch('nexa:identity:cb:listCharacters')
    local response = lib.callback.await('nexa:identity:cb:listCharacters', false)
    markListReturned()

    if response == nil or not response.success then
        debugLog('listCharacters failed', {
            code = response and response.code or nil
        })
        notify(response)
        return
    end

    local characters = response.data.characters or {}
    local options = {}

    debugLog('listCharacters succeeded', {
        count = #characters,
        maxCharacters = response.meta and response.meta.maxCharacters or nil
    })

    for _, character in ipairs(characters) do
        options[#options + 1] = {
            title = formatCharacterTitle(character),
            description = ('CitizenID: %s'):format(character.citizenid),
            icon = 'user',
            onSelect = function()
                debugLog('selectCharacter requested', {
                    characterId = character.id,
                    citizenid = character.citizenid
                })
                local markSelectReturned = debugCallbackWatch('nexa:identity:cb:selectCharacter')
                local selected = lib.callback.await('nexa:identity:cb:selectCharacter', false, character.id)
                markSelectReturned()
                debugLog('4 Servercallback erfolgreich: selectCharacter returned', {
                    success = selected and selected.success or false,
                    code = selected and selected.code or nil,
                    characterId = character.id
                })

                if selected ~= nil and selected.success then
                    identitySelectionCompleted = true
                    cleanupIdentityUi('selectCharacter success')
                end

                notify(selected)
            end
        }
    end

    if #characters < response.meta.maxCharacters then
        options[#options + 1] = {
            title = 'Neuen Charakter erstellen',
            icon = 'user-plus',
            onSelect = openCreateDialog
        }
    end

    lib.registerContext({
        id = 'nexa_identity_character_manager',
        title = 'Charakterauswahl',
        options = options
    })

    lib.showContext('nexa_identity_character_manager')
end

RegisterNetEvent(NEXA_IDENTITY_EVENTS.openManager, openCharacterManager)

exports('openCharacterManager', openCharacterManager)
