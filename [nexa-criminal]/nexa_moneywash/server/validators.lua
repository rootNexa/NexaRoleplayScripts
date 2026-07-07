local function normalizeText(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    local text = value:gsub('^%s+', ''):gsub('%s+$', '')

    if text == '' or #text > maxLength or text:match('^[%w_]+$') == nil then
        return nil
    end

    return text
end

local function normalizeAmount(value)
    local amount = tonumber(value)

    if amount == nil or amount < 1 or amount > 1000 or math.floor(amount) ~= amount then
        return nil
    end

    return amount
end

local function normalizeId(value)
    local id = tonumber(value)

    if id == nil or id < 1 or math.floor(id) ~= id then
        return nil
    end

    return id
end

function validateMoneywashPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(payload.stationId, 64) == nil or normalizeAmount(payload.amount) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.accountId ~= nil and normalizeId(payload.accountId) == nil then
        return false, 'INVALID_INPUT'
    end

    if payload.accountNumber ~= nil and normalizeText(payload.accountNumber, 32) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
