local registry = {}

for contractName, contract in pairs(NexaApiContracts) do
    registry[contractName] = contract
end

function getContractInternal(name)
    if type(name) ~= 'string' or name == '' then
        return nil
    end

    return registry[name]
end

function listContractsInternal()
    local result = {}

    for contractName, contract in pairs(registry) do
        result[contractName] = contract
    end

    return result
end
