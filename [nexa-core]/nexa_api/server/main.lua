function getStatus()
    return {
        resourceName = NEXA_API.resourceName,
        version = NEXA_API.version,
        contracts = listContractsInternal(),
        qbox = getQboxBridgeStatus()
    }
end

function getContract(name)
    local contract = getContractInternal(name)

    if contract == nil then
        return NexaApiResponse(false, 'NOT_FOUND', 'API-Contract wurde nicht gefunden.', nil, nil, nil)
    end

    return NexaApiResponse(true, 'OK', 'API-Contract wurde geladen.', contract, nil, nil)
end

function listContracts()
    return listContractsInternal()
end

function buildResponse(success, code, message, data, meta, auditId)
    return NexaApiResponse(success, code, message, data, meta, auditId)
end

exports('getStatus', getStatus)
exports('getContract', getContract)
exports('listContracts', listContracts)
exports('buildResponse', buildResponse)
