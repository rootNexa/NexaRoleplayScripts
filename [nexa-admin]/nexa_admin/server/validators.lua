local function normalizeText(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' or #trimmed > maxLength then
        return nil
    end

    return trimmed
end

function validateAdminActionPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(payload.actionId, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.targetSource ~= nil and tonumber(payload.targetSource) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateReportCreatePayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local subject = normalizeText(payload.subject, 80)
    local message = normalizeText(payload.message, 1000)
    local category = normalizeText(payload.category or 'support', 32)

    if subject == nil or #subject < 8 or message == nil or #message < 16 or category == nil then
        return false, 'INVALID_INPUT'
    end

    if NexaAdminServer.reports.categories[category] == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK', {
        subject = subject,
        message = message,
        category = category
    }
end

function validateReportIdPayload(payload)
    if type(payload) ~= 'table' or normalizeText(payload.reportId, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateReportClosePayload(payload)
    local valid, code = validateReportIdPayload(payload)

    if not valid then
        return false, code
    end

    local reason = normalizeText(payload.reason or 'Bearbeitet', 240)

    if reason == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK', {
        reason = reason
    }
end

function validateTicketCreatePayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local reason = normalizeText(payload.reason, 32)
    local description = normalizeText(payload.description, 1000)

    if reason == nil or description == nil or #description < 12 then
        return false, 'INVALID_INPUT'
    end

    if NexaAdminServer.tickets.reasons[reason] == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK', {
        reason = reason,
        description = description
    }
end

function validateTicketIdPayload(payload)
    if type(payload) ~= 'table' or normalizeText(payload.ticketId, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateTicketAssignPayload(payload)
    local valid, code = validateTicketIdPayload(payload)

    if not valid then
        return false, code
    end

    if payload.assigneeSource ~= nil and tonumber(payload.assigneeSource) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateTicketClosePayload(payload)
    local valid, code = validateTicketIdPayload(payload)

    if not valid then
        return false, code
    end

    local note = normalizeText(payload.note or 'Bearbeitet', 240)

    if note == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK', {
        note = note
    }
end

local function validateTargetSource(value)
    local targetSource = tonumber(value)

    if targetSource == nil or targetSource < 1 then
        return nil
    end

    return targetSource
end

function validateModerationReasonPayload(payload, maxLength, minLength)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local targetSource = validateTargetSource(payload.targetSource)
    local reason = normalizeText(payload.reason, maxLength or 240)

    if targetSource == nil or reason == nil or #reason < (minLength or 3) then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK', {
        targetSource = targetSource,
        reason = reason
    }
end

function validateModerationFreezePayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local targetSource = validateTargetSource(payload.targetSource)
    local state = normalizeText(payload.state, 16)
    local reason = normalizeText(payload.reason or 'Moderationsmassnahme', 240)

    if targetSource == nil or state == nil or reason == nil then
        return false, 'INVALID_INPUT'
    end

    if NexaAdminServer.moderation.allowedFreezeStates[state] ~= true then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK', {
        targetSource = targetSource,
        state = state,
        frozen = state == 'frozen',
        reason = reason
    }
end

function validateTempbanPreparePayload(payload)
    local valid, code, sanitized = validateModerationReasonPayload(payload, 240, 3)

    if not valid then
        return false, code
    end

    local durationMinutes = tonumber(payload.durationMinutes)

    if durationMinutes == nil or durationMinutes < 5 or durationMinutes > 43200 then
        return false, 'INVALID_INPUT'
    end

    sanitized.durationMinutes = math.floor(durationMinutes)

    return true, 'OK', sanitized
end

function validateModerationNotePayload(payload)
    local valid, code, sanitized = validateModerationReasonPayload(payload, 1000, 4)

    if not valid then
        return false, code
    end

    sanitized.note = sanitized.reason
    sanitized.reason = nil

    return true, 'OK', sanitized
end

function validateModerationTargetPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local targetSource = validateTargetSource(payload.targetSource)

    if targetSource == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK', {
        targetSource = targetSource
    }
end

local function validateCoordinate(value)
    local number = tonumber(value)

    if number == nil then
        return nil
    end

    if math.abs(number) > NexaAdminServer.utility.maxCoordinateDistance then
        return nil
    end

    return number
end

function validateUtilityTargetPayload(payload)
    return validateModerationTargetPayload(payload)
end

function validateUtilityCoordsPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local x = validateCoordinate(payload.x)
    local y = validateCoordinate(payload.y)
    local z = validateCoordinate(payload.z)
    local heading = tonumber(payload.heading or 0.0)

    if x == nil or y == nil or z == nil or heading == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK', {
        x = x,
        y = y,
        z = z,
        heading = heading
    }
end

function validateUtilityPreparedPayload(payload)
    local valid, code, sanitized = validateUtilityTargetPayload(payload)

    if not valid then
        return false, code
    end

    local reason = normalizeText(payload.reason or 'Admin-Utility', 240)

    if reason == nil then
        return false, 'INVALID_INPUT'
    end

    sanitized.reason = reason

    return true, 'OK', sanitized
end
