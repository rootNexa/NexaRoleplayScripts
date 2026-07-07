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

lib.callback.register(NexaPhoneConfig.snapshotCallback, function(source)
    if not checkRequest(source, NexaPhoneServerConfig.callbacks.snapshot) then
        return NexaPhoneBuildResponse(false, 'RATE_LIMITED', 'Bitte warte einen Moment.', nil, nil)
    end

    return NexaPhoneBuildResponse(true, 'OK', 'Telefon-Daten wurden geladen.', NexaPhoneGetSnapshot(source), {
        voiceSystem = false,
        persistence = 'session'
    })
end)

lib.callback.register(NexaPhoneConfig.saveNoteCallback, function(source, payload)
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

lib.callback.register(NexaPhoneConfig.sendMessageCallback, function(source, payload)
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
