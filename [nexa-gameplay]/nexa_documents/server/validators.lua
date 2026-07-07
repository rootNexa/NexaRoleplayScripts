local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeText(value)
    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')

    if trimmed == '' then
        return nil
    end

    return trimmed
end

function validateDocumentIssuePayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeId(payload.ownerCharacterId) == nil then
        return false, 'INVALID_INPUT'
    end

    if normalizeId(payload.documentTypeId) == nil and normalizeText(payload.documentType) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.data ~= nil and type(payload.data) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.expiresAt ~= nil and (type(payload.expiresAt) ~= 'string' or not payload.expiresAt:match('^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$')) then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateDocumentRevokePayload(payload)
    if type(payload) ~= 'table' or normalizeId(payload.documentId) == nil then
        return false, 'INVALID_INPUT'
    end

    local reason = normalizeText(payload.reason)

    if reason ~= nil and #reason > NexaDocumentsConfig.maxReasonLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateDocumentValidationPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local documentNumber = normalizeText(payload.documentNumber)

    if normalizeId(payload.documentId) == nil and (documentNumber == nil or #documentNumber > 32) then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
