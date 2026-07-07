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

local function normalizeAmount(value, maxAmount)
    local amount = tonumber(value)

    if amount == nil or amount < 1 or amount > maxAmount or math.floor(amount) ~= amount then
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

function validateDrugPlantPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(payload.cropId, 64) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateDrugHarvestPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeId(payload.batchId) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateDrugProcessPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(payload.recipeId, 64) == nil or normalizeAmount(payload.amount, 25) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateDrugSellPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if normalizeText(payload.buyerId, 64) == nil or normalizeAmount(payload.amount, 25) == nil then
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
