local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaDrugsConfig.featureFlag)
end

local function getStatus()
    return {
        resourceName = NEXA_DRUGS.resourceName,
        version = NEXA_DRUGS.version,
        enabled = isEnabled(),
        illegalCore = GetResourceState('nexa_illegal_core') == 'started'
    }
end

local function buildConfigPayload()
    return {
        crops = NexaDrugsServer.crops,
        recipes = NexaDrugsServer.recipes,
        buyers = NexaDrugsServer.buyers
    }
end

local function plant(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Drogensystem ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.drugsPlant'](source, payload, buildConfigPayload())
end

local function harvest(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Drogensystem ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.drugsHarvest'](source, payload, buildConfigPayload())
end

local function process(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Drogensystem ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.drugsProcess'](source, payload, buildConfigPayload())
end

local function sell(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Drogensystem ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.drugsSell'](source, payload, buildConfigPayload())
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_DRUGS.resourceName, 'Drogensystem gestartet.', {
        version = NEXA_DRUGS.version,
        featureFlag = NexaDrugsConfig.featureFlag
    })
end)

exports('getStatus', getStatus)
exports('drugs.plant', plant)
exports('drugs.harvest', harvest)
exports('drugs.process', process)
exports('drugs.sell', sell)
