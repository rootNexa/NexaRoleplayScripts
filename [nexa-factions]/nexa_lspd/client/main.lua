local function notify(title, description, noticeType)
    exports.nexa_ui:notify({
        title = title,
        message = description,
        type = noticeType or 'info'
    })
end

local function normalizeCallbackResponse(response)
    if type(response) ~= 'table' then
        return nil
    end

    if response.success ~= nil then
        return response
    end

    if response.ok == true and type(response.data) == 'table' and response.data.success ~= nil then
        return response.data
    end

    if response.ok == false then
        local error = response.error or {}

        return {
            success = false,
            code = error.code,
            message = error.message or 'Anfrage fehlgeschlagen.',
            meta = error.details
        }
    end

    return response
end

local function awaitServerCallback(name, payload)
    local pending = promise.new()
    local request = exports.nexa_api:TriggerServerCallback(name, payload or {}, function(response)
        pending:resolve(normalizeCallbackResponse(response))
    end)

    if type(request) == 'table' and request.ok == false then
        return normalizeCallbackResponse(request)
    end

    return Citizen.Await(pending)
end

local factionCoreCallbacks = {
    overview = 'nexa:factions_core:cb:getOverview',
    members = 'nexa:factions_core:cb:listMembers'
}

local factionCoreEvents = {
    toggleDuty = 'nexa:factions_core:server:requestToggleDuty',
    setCallsign = 'nexa:factions_core:server:requestSetCallsign'
}

RegisterNetEvent(NEXA_LSPD_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    notify('LSPD', response.message, response.success and 'success' or 'error')
end)

local function openMdt()
    local response = awaitServerCallback('nexa:lspd:cb:getRecordsStatus', {})

    if type(response) ~= 'table' or response.success ~= true then
        notify('LSPD', response and response.message or 'Aktenzugriff ist derzeit nicht verfuegbar.', 'error')
        return
    end

    local mdt = response.data and response.data.mdt or {}

    if not mdt.started then
        notify('LSPD', 'Das MDT ist derzeit nicht gestartet.', 'error')
        return
    end

    if not mdt.canOpen then
        notify('LSPD', 'Du darfst das MDT derzeit nicht oeffnen.', 'error')
        return
    end

    exports.nexa_mdt:open()
end

local function openDispatchMenu()
    local response = awaitServerCallback('nexa:lspd:cb:listDispatch', {
        status = 'open'
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify('LSPD', response and response.message or 'Dispatch konnte nicht geladen werden.', 'error')
        return
    end

    local calls = response.data and response.data.calls or {}
    local options = {}

    if #calls == 0 then
        options[#options + 1] = {
            title = 'Keine offenen Einsaetze',
            disabled = true
        }
    else
        for index = 1, math.min(#calls, NexaLspdClient.maxDispatchPreview) do
            local call = calls[index]
            options[#options + 1] = {
                title = ('%s | %s'):format(call.call_number or 'Unbekannt', call.category or 'general'),
                description = ('Status: %s | Prioritaet: %s'):format(call.status or 'offen', tostring(call.priority or '?')),
                disabled = true
            }
        end
    end

    exports.nexa_ui:registerContext({
        id = 'nexa_lspd_dispatch_menu',
        title = 'LSPD Dispatch',
        options = options
    })

    exports.nexa_ui:showContext('nexa_lspd_dispatch_menu')
end

local function openMembersMenu()
    local response = awaitServerCallback(factionCoreCallbacks.members, {
        factionName = NexaLspdConfig.factionName,
        limit = NexaLspdClient.maxMemberPreview
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify('LSPD', response and response.message or 'Mitglieder konnten nicht geladen werden.', 'error')
        return
    end

    local members = response.data and response.data.members or {}
    local options = {}

    if #members == 0 then
        options[#options + 1] = {
            title = 'Keine aktiven Mitglieder',
            disabled = true
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
                disabled = true
            }
        end
    end

    exports.nexa_ui:registerContext({
        id = 'nexa_lspd_members_menu',
        title = 'LSPD Mitglieder',
        options = options
    })

    exports.nexa_ui:showContext('nexa_lspd_members_menu')
end

local function openLspdMenu()
    local response = awaitServerCallback(factionCoreCallbacks.overview, {
        factionName = NexaLspdConfig.factionName
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify('LSPD', response and response.message or 'LSPD-Status konnte nicht geladen werden.', 'error')
        return
    end

    local recordsResponse = awaitServerCallback('nexa:lspd:cb:getRecordsStatus', {})
    local mdt = {}

    if type(recordsResponse) == 'table' and recordsResponse.success == true then
        mdt = recordsResponse.data and recordsResponse.data.mdt or {}
    end

    local membership = response.data and response.data.membership or nil
    local dutySession = response.data and response.data.dutySession or nil
    local radioChannels = response.data and response.data.radioChannels or {}
    local statusText = 'Keine aktive LSPD-Mitgliedschaft.'

    if membership ~= nil then
        statusText = ('%s | %s'):format(membership.faction.label, membership.grade.label)

        if membership.callsign ~= nil and membership.callsign ~= '' then
            statusText = ('%s | Callsign %s'):format(statusText, membership.callsign)
        end
    end

    local dispatchHint = 'Kein Funkkanal hinterlegt.'

    if radioChannels[1] ~= nil then
        dispatchHint = ('Funk: %s (%.2f)'):format(radioChannels[1].label or radioChannels[1].name or 'LSPD', radioChannels[1].frequency or 0.0)
    end

    exports.nexa_ui:registerContext({
        id = 'nexa_lspd_menu',
        title = 'LSPD',
        options = {
            {
                title = 'Status',
                description = statusText,
                disabled = true
            },
            {
                title = 'Dienst',
                description = dutySession ~= nil and 'Du bist im Dienst.' or 'Du bist nicht im Dienst.',
                disabled = membership == nil,
                serverEvent = factionCoreEvents.toggleDuty,
                args = {
                    factionName = NexaLspdConfig.factionName
                }
            },
            {
                title = 'Callsign setzen',
                description = dispatchHint,
                disabled = membership == nil,
                onSelect = function()
                    local input = exports.nexa_ui:inputDialog('LSPD Callsign', {
                        {
                            type = 'input',
                            label = 'Callsign',
                            required = false,
                            maxLength = NexaLspdConfig.maxCallsignLength
                        }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(factionCoreEvents.setCallsign, {
                        factionName = NexaLspdConfig.factionName,
                        callsign = input[1]
                    })
                end
            },
            {
                title = 'Dispatch lesen',
                description = 'Laedt offene Einsaetze ueber die Dispatch-API.',
                disabled = membership == nil,
                onSelect = openDispatchMenu
            },
            {
                title = 'Mitglieder',
                description = 'Zeigt LSPD-Raenge und aktive Mitgliedschaften.',
                disabled = membership == nil,
                onSelect = openMembersMenu
            },
            {
                title = 'MDT oeffnen',
                description = mdt.started and 'Vorhandenes MDT fuer Basis-Aktenzugriff oeffnen.' or 'MDT ist derzeit nicht verfuegbar.',
                disabled = membership == nil or not mdt.started,
                onSelect = openMdt
            }
        }
    })

    exports.nexa_ui:showContext('nexa_lspd_menu')
end

RegisterCommand(NexaLspdConfig.commandName, function()
    if not NexaLspdClient.enableContextMenu then
        return
    end

    openLspdMenu()
end, false)
