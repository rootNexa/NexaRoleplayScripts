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

RegisterNetEvent(NEXA_EMS_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    notify('EMS', response.message, response.success and 'success' or 'error')
end)

local function openMembersMenu()
    local response = lib.callback.await(factionCoreCallbacks.members, false, {
        factionName = NexaEmsConfig.factionName,
        limit = NexaEmsClient.maxMemberPreview
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify('EMS', response and response.message or 'Mitglieder konnten nicht geladen werden.', 'error')
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
        id = 'nexa_ems_members_menu',
        title = 'EMS Mitglieder',
        options = options
    })

    lib.showContext('nexa_ems_members_menu')
end

local function openRecordsMenu()
    local response = lib.callback.await('nexa:ems:cb:listRecords', false, {
        limit = NexaEmsClient.maxRecordPreview
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify('EMS', response and response.message or 'Patientenakten konnten nicht geladen werden.', 'error')
        return
    end

    local records = response.data and response.data.records or {}
    local options = {}

    if #records == 0 then
        options[#options + 1] = {
            title = 'Keine Patientenakten',
            readOnly = true
        }
    else
        for _, record in ipairs(records) do
            local patient = ('%s %s'):format(record.firstname or 'Unbekannt', record.lastname or '')

            options[#options + 1] = {
                title = ('#%s | %s'):format(record.id, patient),
                description = ('%s | %s'):format(record.record_type or 'patient_contact', record.status or 'open'),
                readOnly = true
            }
        end
    end

    lib.registerContext({
        id = 'nexa_ems_records_menu',
        title = 'EMS Patientenakten',
        options = options
    })

    lib.showContext('nexa_ems_records_menu')
end

local function requestCreateRecord()
    local input = lib.inputDialog('Patientenakte', {
        {
            type = 'number',
            label = 'Charakter-ID',
            required = true,
            min = 1
        },
        {
            type = 'input',
            label = 'Typ',
            required = false,
            max = 64
        },
        {
            type = 'textarea',
            label = 'Zusammenfassung',
            required = false,
            max = 500
        }
    })

    if input == nil then
        return
    end

    TriggerServerEvent(NEXA_EMS_EVENTS.requestCreateRecord, {
        characterId = input[1],
        recordType = input[2],
        summary = input[3]
    })
end

local function requestAddTreatment()
    local input = lib.inputDialog('Behandlung', {
        {
            type = 'number',
            label = 'Akten-ID',
            required = true,
            min = 1
        },
        {
            type = 'input',
            label = 'Behandlungstyp',
            required = true,
            max = 64
        },
        {
            type = 'textarea',
            label = 'Notizen',
            required = false,
            max = 500
        }
    })

    if input == nil then
        return
    end

    TriggerServerEvent(NEXA_EMS_EVENTS.requestAddTreatment, {
        recordId = input[1],
        treatmentType = input[2],
        notes = input[3]
    })
end

local function requestCreateInvoice()
    local input = lib.inputDialog('Medizinische Rechnung', {
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
            max = NexaEmsConfig.maxInvoiceAmount
        },
        {
            type = 'input',
            label = 'Grund',
            required = true,
            max = 128
        },
        {
            type = 'number',
            label = 'Akten-ID',
            required = false,
            min = 1
        }
    })

    if input == nil then
        return
    end

    TriggerServerEvent(NEXA_EMS_EVENTS.requestCreateInvoice, {
        characterId = input[1],
        amount = input[2],
        reason = input[3],
        recordId = input[4]
    })
end

local function openEmsMenu()
    local response = lib.callback.await(factionCoreCallbacks.overview, false, {
        factionName = NexaEmsConfig.factionName
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify('EMS', response and response.message or 'EMS-Status konnte nicht geladen werden.', 'error')
        return
    end

    local statusResponse = lib.callback.await('nexa:ems:cb:getStatus', false)
    local emsPermissions = {}

    if type(statusResponse) == 'table' and statusResponse.success == true then
        emsPermissions = statusResponse.data and statusResponse.data.emsPermissions or {}
    end

    local membership = response.data and response.data.membership or nil
    local dutySession = response.data and response.data.dutySession or nil
    local radioChannels = response.data and response.data.radioChannels or {}
    local statusText = 'Keine aktive EMS-Mitgliedschaft.'

    if membership ~= nil then
        statusText = ('%s | %s'):format(membership.faction.label, membership.grade.label)

        if membership.callsign ~= nil and membership.callsign ~= '' then
            statusText = ('%s | Callsign %s'):format(statusText, membership.callsign)
        end
    end

    local radioHint = 'Kein Funkkanal hinterlegt.'

    if radioChannels[1] ~= nil then
        radioHint = ('Funk: %s (%.2f)'):format(radioChannels[1].label or radioChannels[1].name or 'EMS', radioChannels[1].frequency or 0.0)
    end

    lib.registerContext({
        id = 'nexa_ems_menu',
        title = 'EMS',
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
                    factionName = NexaEmsConfig.factionName
                }
            },
            {
                title = 'Callsign setzen',
                description = radioHint,
                disabled = membership == nil,
                onSelect = function()
                    local input = lib.inputDialog('EMS Callsign', {
                        {
                            type = 'input',
                            label = 'Callsign',
                            required = false,
                            max = NexaEmsConfig.maxCallsignLength
                        }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(factionCoreEvents.setCallsign, {
                        factionName = NexaEmsConfig.factionName,
                        callsign = input[1]
                    })
                end
            },
            {
                title = 'Mitglieder',
                description = 'Zeigt EMS-Raenge und aktive Mitgliedschaften.',
                disabled = membership == nil,
                onSelect = openMembersMenu
            },
            {
                title = 'Patientenakten',
                description = 'Laedt einfache EMS-Akten.',
                disabled = membership == nil or not emsPermissions.recordsView,
                onSelect = openRecordsMenu
            },
            {
                title = 'Akte erstellen',
                description = 'Erfasst eine einfache Patientenakte.',
                disabled = membership == nil or not emsPermissions.recordsCreate,
                onSelect = requestCreateRecord
            },
            {
                title = 'Behandlung erfassen',
                description = 'Fuegt einer Akte eine einfache Behandlung hinzu.',
                disabled = membership == nil or not emsPermissions.treatmentCreate,
                onSelect = requestAddTreatment
            },
            {
                title = 'Rechnung erstellen',
                description = 'Erstellt eine medizinische Rechnung ueber die Account-API.',
                disabled = membership == nil or not emsPermissions.billingCreate,
                onSelect = requestCreateInvoice
            }
        }
    })

    lib.showContext('nexa_ems_menu')
end

RegisterCommand(NexaEmsConfig.commandName, function()
    if not NexaEmsClient.enableOxContext then
        return
    end

    openEmsMenu()
end, false)
