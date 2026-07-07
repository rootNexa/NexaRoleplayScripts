local function normalizeId(value)
    local number = tonumber(value)

    if number == nil or number <= 0 then
        return nil
    end

    return math.floor(number)
end

local function normalizeAmount(value)
    local number = tonumber(value)

    if number == nil or number < 1 or number > NexaBankingConfig.maxAmount then
        return nil
    end

    if math.floor(number) ~= number then
        return nil
    end

    return number
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

local function hasAccountReference(payload, idKey, numberKey)
    if normalizeId(payload[idKey]) ~= nil then
        return true
    end

    local accountNumber = normalizeText(payload[numberKey])

    return accountNumber ~= nil and #accountNumber <= 32
end

function validateCreatePrivateAccountPayload(payload)
    if payload == nil then
        return true, 'OK'
    end

    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if payload.accountType ~= nil and payload.accountType ~= 'checking' and payload.accountType ~= 'savings' then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateAccountReferencePayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if not hasAccountReference(payload, 'accountId', 'accountNumber') then
        return false, 'INVALID_INPUT'
    end

    if payload.limit ~= nil and normalizeId(payload.limit) == nil then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validateTransferPayload(payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_INPUT'
    end

    if not hasAccountReference(payload, 'fromAccountId', 'fromAccountNumber') then
        return false, 'INVALID_INPUT'
    end

    if not hasAccountReference(payload, 'toAccountId', 'toAccountNumber') then
        return false, 'INVALID_INPUT'
    end

    if normalizeAmount(payload.amount) == nil then
        return false, 'INVALID_INPUT'
    end

    local reason = normalizeText(payload.reason)

    if reason ~= nil and #reason > NexaBankingConfig.maxReasonLength then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end

function validatePayInvoicePayload(payload)
    if type(payload) ~= 'table' or normalizeId(payload.invoiceId) == nil then
        return false, 'INVALID_INPUT'
    end

    if not hasAccountReference(payload, 'fromAccountId', 'fromAccountNumber') then
        return false, 'INVALID_INPUT'
    end

    return true, 'OK'
end
