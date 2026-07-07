local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeAmount(value)
    local number = tonumber(value)

    if number == nil or number <= 0 or number > NexaGovernmentServer.maxInvoiceAmount then
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

local function validateTypeName(value)
    local normalized = normalizeText(value, nil)

    if normalized == nil or #normalized > 64 or normalized:find('[^%w_%-]') ~= nil then
        return nil
    end

    return normalized
end

function validateGovernmentCallsignPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.characterId ~= nil and normalizeId(payload.characterId) == nil then
        return false, 'INVALID_INPUT'
    end

    local callsign = normalizeText(payload.callsign, nil)

    if callsign ~= nil and #callsign > NexaGovernmentConfig.maxCallsignLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateGovernmentMemberPayload(payload)
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

function validateGovernmentDocumentIssuePayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local ownerCharacterId = normalizeId(payload.ownerCharacterId)
    local documentType = validateTypeName(payload.documentType)
    local documentTypeId = normalizeId(payload.documentTypeId)

    if ownerCharacterId == nil or (documentType == nil and documentTypeId == nil) then
        return false, 'INVALID_INPUT'
    end

    if payload.data ~= nil and type(payload.data) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local encodedData = json.encode(payload.data or {})

    if encodedData == nil or #encodedData > NexaGovernmentServer.maxDocumentDataLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateGovernmentDocumentRevokePayload(payload)
    if type(payload) ~= 'table' or normalizeId(payload.documentId) == nil then
        return false, 'INVALID_INPUT'
    end

    local reason = normalizeText(payload.reason, nil)

    if reason ~= nil and #reason > NexaGovernmentServer.maxReasonLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateGovernmentLicenseIssuePayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local characterId = normalizeId(payload.characterId)
    local licenseType = validateTypeName(payload.licenseType)
    local licenseTypeId = normalizeId(payload.licenseTypeId)
    local reason = normalizeText(payload.reason, nil)

    if characterId == nil or (licenseType == nil and licenseTypeId == nil) then
        return false, 'INVALID_INPUT'
    end

    if reason ~= nil and #reason > NexaGovernmentServer.maxReasonLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateGovernmentLicenseRevokePayload(payload)
    if type(payload) ~= 'table' or normalizeId(payload.licenseId) == nil then
        return false, 'INVALID_INPUT'
    end

    local reason = normalizeText(payload.reason, nil)

    if reason ~= nil and #reason > NexaGovernmentServer.maxReasonLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateGovernmentInvoicePayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local characterId = normalizeId(payload.characterId)
    local amount = normalizeAmount(payload.amount)
    local reason = normalizeText(payload.reason, nil)

    if characterId == nil or amount == nil or reason == nil or #reason > NexaGovernmentServer.maxReasonLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
