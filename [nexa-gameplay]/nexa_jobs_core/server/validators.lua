local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

function validateJobReferencePayload(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.jobId ~= nil and normalizeId(payload.jobId) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateAssignJobPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeId(payload.characterId) == nil then
        return false, 'INVALID_INPUT'
    end

    if type(payload.jobName) ~= 'string' or payload.jobName == '' or #payload.jobName > NexaJobsConfig.maxJobNameLength then
        return false, 'INVALID_INPUT'
    end

    if payload.gradeLevel ~= nil then
        local grade = tonumber(payload.gradeLevel)

        if grade == nil or grade < 0 or math.floor(grade) ~= grade then
            return false, 'INVALID_INPUT'
        end
    end

    return true, 'OK'
end
