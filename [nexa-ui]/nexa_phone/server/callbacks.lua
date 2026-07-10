local function checkRequest(source, callbackName)
    if GetResourceState('nexa_security') ~= 'started' then
        return true
    end

    if not exports.nexa_security:validateSource(source) then
        return false
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, callbackName)

    return rateLimit ~= nil and rateLimit.success == true
end

local function audit(action, source, metadata)
    if GetResourceState('nexa_audit') ~= 'started' then
        return
    end

    exports.nexa_audit:write({
        eventType = 'phone',
        severity = 'info',
        action = action,
        resourceName = 'nexa_phone',
        metadata = metadata or {
            source = source
        }
    })
end

local function logInfo(message, metadata)
    if GetResourceState('nexa_logs') == 'started' then
        exports.nexa_logs:info('nexa_phone', message, metadata or {})
    end
end

local function validateNote(payload)
    if type(payload) ~= 'table' then
        return nil, 'INVALID_INPUT'
    end

    local title = NexaPhoneLimitText(payload.title, NexaPhoneServerConfig.limits.maxTitleLength)
    local body = NexaPhoneLimitText(payload.body, NexaPhoneServerConfig.limits.maxBodyLength)

    if title == '' or body == '' then
        return nil, 'INVALID_INPUT'
    end

    return {
        title = title,
        body = body
    }, 'OK'
end

local function validateMessage(payload)
    if type(payload) ~= 'table' then
        return nil, 'INVALID_INPUT'
    end

    local recipient = NexaPhoneLimitText(payload.recipient, NexaPhoneServerConfig.limits.maxRecipientLength)
    local body = NexaPhoneLimitText(payload.body, NexaPhoneServerConfig.limits.maxMessageLength)

    if recipient == '' or body == '' then
        return nil, 'INVALID_INPUT'
    end

    return {
        recipient = recipient,
        body = body
    }, 'OK'
end

exports.nexa_api:RegisterServerCallback(NexaPhoneConfig.snapshotCallback, function(source)
    if not checkRequest(source, NexaPhoneServerConfig.callbacks.snapshot) then
        return NexaPhoneBuildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil)
    end

    return NexaPhoneBuildResponse(true, 'OK', 'Telefon-Daten wurden geladen.', NexaPhoneGetSnapshot(source), {
        voiceSystem = false,
        persistence = 'session'
    })
end)

exports.nexa_api:RegisterServerCallback(NexaPhoneConfig.saveNoteCallback, function(source, payload)
    if not checkRequest(source, NexaPhoneServerConfig.callbacks.saveNote) then
        return NexaPhoneBuildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil)
    end

    local note, code = validateNote(payload)

    if note == nil then
        return NexaPhoneBuildResponse(false, code, 'Eingabe wurde abgelehnt.', nil, nil)
    end

    local entry = NexaPhoneAddNote(source, note.title, note.body)
    audit('phone.note.save', source, {
        source = source,
        noteId = entry.id
    })
    logInfo('Phone-Notiz wurde gespeichert.', {
        source = source,
        noteId = entry.id
    })

    return NexaPhoneBuildResponse(true, 'OK', 'Notiz wurde gespeichert.', {
        note = entry,
        snapshot = NexaPhoneGetSnapshot(source)
    }, nil)
end)

exports.nexa_api:RegisterServerCallback(NexaPhoneConfig.sendMessageCallback, function(source, payload)
    if not checkRequest(source, NexaPhoneServerConfig.callbacks.sendMessage) then
        return NexaPhoneBuildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil)
    end

    local message, code = validateMessage(payload)

    if message == nil then
        return NexaPhoneBuildResponse(false, code, 'Eingabe wurde abgelehnt.', nil, nil)
    end

    local entry = NexaPhoneAddMessage(source, message.recipient, message.body)
    audit('phone.message.queue', source, {
        source = source,
        messageId = entry.id
    })
    logInfo('Phone-Nachricht wurde vorgemerkt.', {
        source = source,
        messageId = entry.id
    })

    return NexaPhoneBuildResponse(true, 'OK', 'Nachricht wurde vorgemerkt.', {
        message = entry,
        snapshot = NexaPhoneGetSnapshot(source)
    }, nil)
end)

exports.nexa_api:RegisterServerCallback(NexaPhoneServerConfig.callbacks.addContact, function(source, payload)
    if not checkRequest(source, NexaPhoneServerConfig.callbacks.addContact) then
        return NexaPhoneBuildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil)
    end

    payload = type(payload) == 'table' and payload or {}
    local name = NexaPhoneLimitText(payload.name or payload.display_name, NexaPhoneServerConfig.limits.maxTitleLength)
    local number = NexaPhoneLimitText(payload.number or payload.phone_number, NexaPhoneServerConfig.limits.maxRecipientLength)

    if name == '' or number == '' then
        return NexaPhoneBuildResponse(false, 'INVALID_INPUT', 'Kontakt wurde abgelehnt.', nil, nil)
    end

    local id = NexaPhoneDatabase.InsertContact({ owner_character_id = tonumber(payload.owner_character_id) or source, display_name = name, phone_number = number, favorite = payload.favorite == true, notes = payload.notes, metadata = payload.metadata or {} })
    audit('phone.contact.add', source, { source = source, contactId = id })
    return NexaPhoneBuildResponse(true, 'OK', 'Kontakt wurde gespeichert.', { contact_id = id }, nil)
end)

exports.nexa_api:RegisterServerCallback(NexaPhoneServerConfig.callbacks.addGroup, function(source, payload)
    payload = type(payload) == 'table' and payload or {}
    local label = NexaPhoneLimitText(payload.label, NexaPhoneServerConfig.limits.maxTitleLength)
    if label == '' then return NexaPhoneBuildResponse(false, 'INVALID_INPUT', 'Gruppe wurde abgelehnt.', nil, nil) end
    local id = NexaPhoneDatabase.InsertGroup({ owner_character_id = tonumber(payload.owner_character_id) or source, label = label, metadata = payload.metadata or {} })
    audit('phone.group.add', source, { source = source, groupId = id })
    return NexaPhoneBuildResponse(true, 'OK', 'Gruppe wurde gespeichert.', { group_id = id }, nil)
end)

exports.nexa_api:RegisterServerCallback(NexaPhoneServerConfig.callbacks.logCall, function(source, payload)
    payload = type(payload) == 'table' and payload or {}
    local number = NexaPhoneLimitText(payload.number or payload.phone_number, NexaPhoneServerConfig.limits.maxRecipientLength)
    if number == '' then return NexaPhoneBuildResponse(false, 'INVALID_INPUT', 'Anruf wurde abgelehnt.', nil, nil) end
    local id = NexaPhoneDatabase.InsertCall({ owner_character_id = tonumber(payload.owner_character_id) or source, phone_number = number, direction = payload.direction or 'outgoing', status = payload.status or 'logged', metadata = payload.metadata or {} })
    return NexaPhoneBuildResponse(true, 'OK', 'Anruf wurde protokolliert.', { call_id = id }, nil)
end)

exports.nexa_api:RegisterServerCallback(NexaPhoneServerConfig.callbacks.savePreferences, function(source, payload)
    payload = type(payload) == 'table' and payload or {}
    local id = NexaPhoneDatabase.InsertPreference(tonumber(payload.owner_character_id) or source, payload)
    return NexaPhoneBuildResponse(true, 'OK', 'Telefon-Einstellungen gespeichert.', { preference_id = id }, nil)
end)

exports.nexa_api:RegisterServerCallback(NexaPhoneServerConfig.callbacks.emergencyCall, function(source, payload)
    payload = type(payload) == 'table' and payload or {}
    if GetResourceState('nexa_dispatch') ~= 'started' then
        return NexaPhoneBuildResponse(false, 'NOT_FOUND', 'Dispatch ist nicht verfuegbar.', nil, nil)
    end

    return exports.nexa_dispatch:CreateDispatchCall({
        call_type = payload.call_type or 'emergency',
        priority = payload.priority or 1,
        caller_character_id = tonumber(payload.character_id) or source,
        location = payload.location or {},
        description = payload.description or 'Notruf ueber Telefon',
        dedupe_key = payload.dedupe_key
    })
end)
