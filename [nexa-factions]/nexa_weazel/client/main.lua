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

RegisterNetEvent(NEXA_WEAZEL_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    notify('Weazel', response.message, response.success and 'success' or 'error')
end)

RegisterNetEvent(NEXA_WEAZEL_EVENTS.announcement, function(announcement)
    if type(announcement) ~= 'table' then
        return
    end

    notify(announcement.title or 'Weazel News', announcement.body or '', 'inform')
end)

local function openMembersMenu()
    local response = lib.callback.await(factionCoreCallbacks.members, false, {
        factionName = NexaWeazelConfig.factionName,
        limit = NexaWeazelClient.maxMemberPreview
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify('Weazel', response and response.message or 'Mitglieder konnten nicht geladen werden.', 'error')
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
        id = 'nexa_weazel_members_menu',
        title = 'Weazel Mitglieder',
        options = options
    })

    lib.showContext('nexa_weazel_members_menu')
end

local function requestIssuePressPass()
    local input = lib.inputDialog('Presseausweis', {
        {
            type = 'number',
            label = 'Charakter-ID',
            required = true,
            min = 1
        },
        {
            type = 'textarea',
            label = 'Notiz',
            required = false,
            max = NexaWeazelConfig.maxPressNoteLength
        }
    })

    if input == nil then
        return
    end

    TriggerServerEvent(NEXA_WEAZEL_EVENTS.requestIssuePressPass, {
        ownerCharacterId = input[1],
        note = input[2]
    })
end

local function requestCreateAnnouncement()
    local input = lib.inputDialog('Weazel Ankuendigung', {
        {
            type = 'input',
            label = 'Titel',
            required = true,
            max = NexaWeazelConfig.maxAnnouncementTitleLength
        },
        {
            type = 'textarea',
            label = 'Text',
            required = true,
            max = NexaWeazelConfig.maxAnnouncementBodyLength
        }
    })

    if input == nil then
        return
    end

    TriggerServerEvent(NEXA_WEAZEL_EVENTS.requestCreateAnnouncement, {
        title = input[1],
        body = input[2]
    })
end

local function openWeazelMenu()
    local response = lib.callback.await(factionCoreCallbacks.overview, false, {
        factionName = NexaWeazelConfig.factionName
    })

    if type(response) ~= 'table' or response.success ~= true then
        notify('Weazel', response and response.message or 'Weazel-Status konnte nicht geladen werden.', 'error')
        return
    end

    local statusResponse = lib.callback.await('nexa:weazel:cb:getStatus', false)
    local reporterPermissions = {}

    if type(statusResponse) == 'table' and statusResponse.success == true then
        reporterPermissions = statusResponse.data and statusResponse.data.reporterPermissions or {}
    end

    local membership = response.data and response.data.membership or nil
    local dutySession = response.data and response.data.dutySession or nil
    local radioChannels = response.data and response.data.radioChannels or {}
    local statusText = 'Keine aktive Weazel-Mitgliedschaft.'

    if membership ~= nil then
        statusText = ('%s | %s'):format(membership.faction.label, membership.grade.label)

        if membership.callsign ~= nil and membership.callsign ~= '' then
            statusText = ('%s | Callsign %s'):format(statusText, membership.callsign)
        end
    end

    local radioHint = 'Kein Funkkanal hinterlegt.'

    if radioChannels[1] ~= nil then
        radioHint = ('Funk: %s (%.2f)'):format(radioChannels[1].label or radioChannels[1].name or 'Weazel', radioChannels[1].frequency or 0.0)
    end

    lib.registerContext({
        id = 'nexa_weazel_menu',
        title = 'Weazel',
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
                    factionName = NexaWeazelConfig.factionName
                }
            },
            {
                title = 'Callsign setzen',
                description = radioHint,
                disabled = membership == nil,
                onSelect = function()
                    local input = lib.inputDialog('Weazel Callsign', {
                        {
                            type = 'input',
                            label = 'Callsign',
                            required = false,
                            max = NexaWeazelConfig.maxCallsignLength
                        }
                    })

                    if input == nil then
                        return
                    end

                    TriggerServerEvent(factionCoreEvents.setCallsign, {
                        factionName = NexaWeazelConfig.factionName,
                        callsign = input[1]
                    })
                end
            },
            {
                title = 'Mitglieder',
                description = 'Zeigt Weazel-Raenge und aktive Mitgliedschaften.',
                disabled = membership == nil or not reporterPermissions.viewMembers,
                onSelect = openMembersMenu
            },
            {
                title = 'Presseausweis ausstellen',
                description = 'Nutzt die bestehende Dokument-API.',
                disabled = membership == nil or not reporterPermissions.pressPassIssue,
                onSelect = requestIssuePressPass
            },
            {
                title = 'Ankuendigung senden',
                description = 'Servervalidierte Weazel-Meldung.',
                disabled = membership == nil or dutySession == nil or not reporterPermissions.announcementCreate,
                onSelect = requestCreateAnnouncement
            }
        }
    })

    lib.showContext('nexa_weazel_menu')
end

RegisterCommand(NexaWeazelConfig.commandName, function()
    if not NexaWeazelClient.enableOxContext then
        return
    end

    openWeazelMenu()
end, false)
