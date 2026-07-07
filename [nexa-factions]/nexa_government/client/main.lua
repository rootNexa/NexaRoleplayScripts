local function notify(title, description, noticeType)
    lib.notify({
        title = title,
        description = description,
        type = noticeType or 'inform'
    })
end

local factionCoreCallbacks = {
    overview = 'nexa:factions_core:cb:getOverview',
    members = 'nexa:factions_core:cb:listMembers'
}

local factionCoreEvents = {
    toggleDuty = 'nexa:factions_core:server:requestToggleDuty',
    setCallsign = 'nexa:factions_core:server:requestSetCallsign'
}

RegisterNetEvent(NEXA_GOVERNMENT_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    notify('Government', response.message, response.success and 'success' or 'error')
end)

local function openMembersMenu()
    local response = lib.callback.await(factionCoreCallbacks.members, false, {
        factionName = NexaGovernmentConfig.factionName,
        limit = NexaGovernmentClient.maxMemberPreview
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify('Government', response and response.message or 'Mitglieder konnten nicht geladen werden.', 'error')
        return
    end

    local members = response.data and response.data.members or {}
    local options = {}

    if #members == 0 then
        options[#options + 1] = {
            title = 'Keine aktiven Mitglieder',
            readOnly = true
        }
    else
        for _, member in ipairs(members) do
            local label = ('%s %s'):format(member.firstname or 'Unbekannt', member.lastname or '')
            local rank = member.grade_label or member.grade_name or 'Unbekannter Rang'
            local description = rank

            if member.callsign ~= nil and member.callsign ~= '' then
                description = ('%s | Callsign %s'):format(description, member.callsign)
            end

            options[#options + 1] = {
                title = label,
                description = description,
                readOnly = true
            }
        end
    end

    lib.registerContext({
        id = 'nexa_government_members_menu',
        title = 'Government Mitglieder',
        options = options
    })

    lib.showContext('nexa_government_members_menu')
end

local function requestIssueDocument()
    local input = lib.inputDialog('Dokument ausstellen', {
        {
            type = 'number',
            label = 'Charakter-ID',
            required = true,
            min = 1
        },
        {
            type = 'input',
            label = 'Dokumenttyp',
            required = true,
            max = 64
        },
        {
            type = 'textarea',
            label = 'Notiz',
            required = false,
            max = 500
        }
    })

    if input == nil then
        return
    end

    TriggerServerEvent(NEXA_GOVERNMENT_EVENTS.requestIssueDocument, {
        ownerCharacterId = input[1],
        documentType = input[2],
        data = {
            note = input[3]
        }
    })
end

local function requestRevokeDocument()
    local input = lib.inputDialog('Dokument widerrufen', {
        {
            type = 'number',
            label = 'Dokument-ID',
            required = true,
            min = 1
        },
        {
            type = 'input',
            label = 'Grund',
            required = false,
            max = 128
        }
    })

    if input == nil then
        return
    end

    TriggerServerEvent(NEXA_GOVERNMENT_EVENTS.requestRevokeDocument, {
        documentId = input[1],
        reason = input[2]
    })
end

local function requestIssueLicense()
    local input = lib.inputDialog('Lizenz ausstellen', {
        {
            type = 'number',
            label = 'Charakter-ID',
            required = true,
            min = 1
        },
        {
            type = 'input',
            label = 'Lizenztyp',
            required = true,
            max = 64
        },
        {
            type = 'input',
            label = 'Grund',
            required = false,
            max = 128
        }
    })

    if input == nil then
        return
    end

    TriggerServerEvent(NEXA_GOVERNMENT_EVENTS.requestIssueLicense, {
        characterId = input[1],
        licenseType = input[2],
        reason = input[3]
    })
end

local function requestRevokeLicense()
    local input = lib.inputDialog('Lizenz entziehen', {
        {
            type = 'number',
            label = 'Lizenz-ID',
            required = true,
            min = 1
        },
        {
            type = 'input',
            label = 'Grund',
            required = false,
            max = 128
        }
    })

    if input == nil then
        return
    end

    TriggerServerEvent(NEXA_GOVERNMENT_EVENTS.requestRevokeLicense, {
        licenseId = input[1],
        reason = input[2]
    })
end

local function requestCreateInvoice()
    local input = lib.inputDialog('Government Gebuehr', {
        {
            type = 'number',
            label = 'Charakter-ID',
            required = true,
            min = 1
        },
        {
            type = 'number',
            label = 'Betrag',
            required = true,
            min = 1,
            max = NexaGovernmentConfig.maxInvoiceAmount
        },
        {
            type = 'input',
            label = 'Grund',
            required = true,
            max = 128
        }
    })

    if input == nil then
        return
    end

    TriggerServerEvent(NEXA_GOVERNMENT_EVENTS.requestCreateInvoice, {
        characterId = input[1],
        amount = input[2],
        reason = input[3]
    })
end

local function openGovernmentMenu()
    local response = lib.callback.await(factionCoreCallbacks.overview, false, {
        factionName = NexaGovernmentConfig.factionName
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify('Government', response and response.message or 'Government-Status konnte nicht geladen werden.', 'error')
        return
    end

    local statusResponse = lib.callback.await('nexa:government:cb:getStatus', false)
    local governmentPermissions = {}

    if type(statusResponse) == 'table' and statusResponse.success == true then
        governmentPermissions = statusResponse.data and statusResponse.data.governmentPermissions or {}
    end

    local membership = response.data and response.data.membership or nil
    local dutySession = response.data and response.data.dutySession or nil
    local radioChannels = response.data and response.data.radioChannels or {}
    local statusText = 'Keine aktive Government-Mitgliedschaft.'

    if membership ~= nil then
        statusText = ('%s | %s'):format(membership.faction.label, membership.grade.label)

        if membership.callsign ~= nil and membership.callsign ~= '' then
            statusText = ('%s | Callsign %s'):format(statusText, membership.callsign)
        end
    end

    local radioHint = 'Kein Funkkanal hinterlegt.'

    if radioChannels[1] ~= nil then
        radioHint = ('Funk: %s (%.2f)'):format(radioChannels[1].label or radioChannels[1].name or 'Government', radioChannels[1].frequency or 0.0)
    end

    lib.registerContext({
        id = 'nexa_government_menu',
        title = 'Government',
        options = {
            {
                title = 'Status',
                description = statusText,
                readOnly = true
            },
            {
                title = 'Dienst',
                description = dutySession ~= nil and 'Du bist im Dienst.' or 'Du bist nicht im Dienst.',
                disabled = membership == nil,
                serverEvent = factionCoreEvents.toggleDuty,
                args = {
                    factionName = NexaGovernmentConfig.factionName
                }
            },
            {
                title = 'Callsign setzen',
                description = radioHint,
                disabled = membership == nil,
                onSelect = function()
                    local input = lib.inputDialog('Government Callsign', {
                        {
                            type = 'input',
                            label = 'Callsign',
                            required = false,
                            max = NexaGovernmentConfig.maxCallsignLength
                        }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(factionCoreEvents.setCallsign, {
                        factionName = NexaGovernmentConfig.factionName,
                        callsign = input[1]
                    })
                end
            },
            {
                title = 'Mitglieder',
                description = 'Zeigt Government-Raenge und aktive Mitgliedschaften.',
                disabled = membership == nil or not governmentPermissions.viewMembers,
                onSelect = openMembersMenu
            },
            {
                title = 'Dokument ausstellen',
                description = 'Nutzt die bestehende Dokument-API.',
                disabled = membership == nil or not governmentPermissions.documentsIssue,
                onSelect = requestIssueDocument
            },
            {
                title = 'Dokument widerrufen',
                description = 'Nutzt die bestehende Dokument-API.',
                disabled = membership == nil or not governmentPermissions.documentsRevoke,
                onSelect = requestRevokeDocument
            },
            {
                title = 'Lizenz ausstellen',
                description = 'Nutzt die bestehende Lizenz-API.',
                disabled = membership == nil or not governmentPermissions.licensesIssue,
                onSelect = requestIssueLicense
            },
            {
                title = 'Lizenz entziehen',
                description = 'Nutzt die bestehende Lizenz-API.',
                disabled = membership == nil or not governmentPermissions.licensesRevoke,
                onSelect = requestRevokeLicense
            },
            {
                title = 'Gebuehr erstellen',
                description = 'Erstellt eine Rechnung ueber die Account-API.',
                disabled = membership == nil or not governmentPermissions.feesCreate,
                onSelect = requestCreateInvoice
            }
        }
    })

    lib.showContext('nexa_government_menu')
end

RegisterCommand(NexaGovernmentConfig.commandName, function()
    if not NexaGovernmentClient.enableOxContext then
        return
    end

    openGovernmentMenu()
end, false)
