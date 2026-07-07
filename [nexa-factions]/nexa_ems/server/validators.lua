local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeAmount(value)
    local number = tonumber(value)

    if number == nil or number <= 0 or number > NexaEmsServer.maxInvoiceAmount then
        return nil
    end

    if math.floor(number) ~= number then
        return nil
    end

    return number
end

local function normalizeText(value, fallback)
    if value == nil then
        return fallback
    end

    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return fallback
    end

    return trimmed
end

function validateEmsCallsignPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.characterId ~= nil and normalizeId(payload.characterId) == nil then
        return false, 'INVALID_INPUT'
    end

    local callsign = normalizeText(payload.callsign, nil)

    if callsign ~= nil and #callsign > NexaEmsConfig.maxCallsignLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateEmsMemberPayload(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.limit ~= nil and normalizeId(payload.limit) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateEmsRecordListPayload(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.characterId ~= nil and normalizeId(payload.characterId) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.limit ~= nil and normalizeId(payload.limit) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateEmsCreateRecordPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local characterId = normalizeId(payload.characterId)
    local recordType = normalizeText(payload.recordType, 'patient_contact')
    local summary = normalizeText(payload.summary, nil)

    if characterId == nil or recordType == nil or #recordType > 64 then
        return false, 'INVALID_INPUT'
    end

    if summary ~= nil and #summary > NexaEmsServer.maxSummaryLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateEmsTreatmentPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local recordId = normalizeId(payload.recordId)
    local treatmentType = normalizeText(payload.treatmentType, nil)
    local notes = normalizeText(payload.notes, nil)

    if recordId == nil or treatmentType == nil or #treatmentType > 64 then
        return false, 'INVALID_INPUT'
    end

    if notes ~= nil and #notes > NexaEmsServer.maxTreatmentNotesLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateEmsInvoicePayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local characterId = normalizeId(payload.characterId)
    local amount = normalizeAmount(payload.amount)
    local reason = normalizeText(payload.reason, nil)

    if characterId == nil or amount == nil or reason == nil or #reason > NexaEmsServer.maxInvoiceReasonLength then
        return false, 'INVALID_INPUT'
    end

    if payload.recordId ~= nil and normalizeId(payload.recordId) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
