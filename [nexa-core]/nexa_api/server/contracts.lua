NexaApiContracts = {
    contracts = {}
}

local function copyTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}

    for key, child in pairs(value) do
        copy[key] = copyTable(child)
    end

    return copy
end

local function normalizeDefinition(definition)
    if type(definition) ~= 'table' then
        return nil
    end

    local normalized = copyTable(NexaApiDefaultContract)

    for key, value in pairs(definition) do
        normalized[key] = value
    end

    return normalized
end

local function validateDefinition(definition)
    if type(definition.version) ~= 'string' or definition.version == '' then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalid_contract, 'Contract version is required.')
    end

    for _, key in ipairs({ 'events', 'callbacks', 'exports', 'schema' }) do
        if type(definition[key]) ~= 'table' then
            return NexaApiResponse.fail(NexaApiConstants.errors.invalid_contract, ('Contract %s must be a table.'):format(key))
        end
    end

    return NexaApiResponse.ok(true)
end

function NexaApiContracts.RegisterContract(name, definition)
    if not NexaApiValidation.isName(name) then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Contract name must be 2-64 characters.')
    end

    local normalized = normalizeDefinition(definition)

    if not normalized then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalid_contract, 'Contract definition must be a table.')
    end

    local valid = validateDefinition(normalized)

    if not valid.ok then
        return valid
    end

    NexaApiContracts.contracts[name] = normalized
    return NexaApiResponse.ok(normalized)
end

function NexaApiContracts.GetContract(name)
    if not NexaApiValidation.isName(name) then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalidInput, 'Contract name must be 2-64 characters.')
    end

    local contract = NexaApiContracts.contracts[name]

    if not contract then
        return NexaApiResponse.fail(NexaApiConstants.errors.notFound, 'Contract is not registered.')
    end

    return NexaApiResponse.ok(contract)
end

function NexaApiContracts.ListContracts()
    local list = {}

    for name, contract in pairs(NexaApiContracts.contracts) do
        list[#list + 1] = {
            name = name,
            version = contract.version,
            events = contract.events,
            callbacks = contract.callbacks,
            exports = contract.exports
        }
    end

    table.sort(list, function(left, right)
        return left.name < right.name
    end)

    return NexaApiResponse.ok(list)
end

function NexaApiContracts.ValidateContractPayload(name, payload)
    local contractResponse = NexaApiContracts.GetContract(name)

    if not contractResponse.ok then
        return contractResponse
    end

    local schema = contractResponse.data.schema or {}

    if type(payload) ~= 'table' then
        return NexaApiResponse.fail(NexaApiConstants.errors.invalid_payload, 'Payload must be a table.')
    end

    if type(schema.required) == 'table' then
        for _, field in ipairs(schema.required) do
            if payload[field] == nil then
                return NexaApiResponse.fail(NexaApiConstants.errors.invalid_payload, 'Payload is missing a required field.', {
                    field = field
                })
            end
        end
    end

    if type(schema.properties) == 'table' then
        for field, rules in pairs(schema.properties) do
            if payload[field] ~= nil then
                local valid = NexaApiValidation.validatePrimitive(payload[field], rules)

                if not valid.ok then
                    valid.error.details = valid.error.details or {}
                    valid.error.details.field = field
                    return valid
                end
            end
        end
    end

    return NexaApiResponse.ok(true)
end
