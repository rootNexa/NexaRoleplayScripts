local allowedEvidenceStatus = {
    stored = true,
    released = true,
    destroyed = true,
    transferred = true
}

local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeText(value, fallback, maxLength)
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

    if maxLength ~= nil and #trimmed > maxLength then
        return nil
    end

    return trimmed
end

function validateEvidenceCollectPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    local evidenceType = normalizeText(payload.evidenceType, NexaEvidenceConfig.defaultEvidenceType, 64)

    if evidenceType == nil or NexaEvidenceServer.evidenceTypes[evidenceType] == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.incidentReportId ~= nil and normalizeId(payload.incidentReportId) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.subjectCharacterId ~= nil and normalizeId(payload.subjectCharacterId) == nil then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(payload.description, '', NexaEvidenceServer.maxDescriptionLength) == nil then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(payload.location, nil, NexaEvidenceServer.maxLocationLength) == nil then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(payload.sampleRef, nil, NexaEvidenceServer.maxSampleRefLength) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.metadata ~= nil and type(payload.metadata) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateEvidenceListPayload(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.incidentReportId ~= nil and normalizeId(payload.incidentReportId) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.subjectCharacterId ~= nil and normalizeId(payload.subjectCharacterId) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.limit ~= nil and normalizeId(payload.limit) == nil then
        return false, 'INVALID_INPUT'
    end

    local status = normalizeText(payload.status, nil, 32)

    if status ~= nil and not allowedEvidenceStatus[status] then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateEvidenceStatusPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeId(payload.evidenceId) == nil then
        return false, 'INVALID_INPUT'
    end

    local status = normalizeText(payload.status, nil, 32)

    if status == nil or not allowedEvidenceStatus[status] then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(payload.reason, nil, NexaEvidenceServer.maxDescriptionLength) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
