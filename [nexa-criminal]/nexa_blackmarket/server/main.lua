local function isEnabled()
    return GetResourceState('nexa_featureflags') ~= 'started'
        or exports.nexa_featureflags:isEnabled(NexaBlackmarketConfig.featureFlag)
end

local function getStatus()
    return {
        resourceName = NEXA_BLACKMARKET.resourceName,
        version = NEXA_BLACKMARKET.version,
        enabled = isEnabled(),
        illegalCore = GetResourceState('nexa_illegal_core') == 'started'
    }
end

local function getCatalog(source)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Blackmarket ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.blackmarketCatalog'](source, {
        dealers = NexaBlackmarketConfig.dealers,
        categories = NexaBlackmarketConfig.categories,
        catalog = NexaBlackmarketServer.catalog
    })
end

local function buy(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Blackmarket ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.blackmarketBuy'](source, payload, NexaBlackmarketServer.catalog)
end

local function sell(source, payload)
    if not isEnabled() then
        return exports.nexa_api:buildResponse(false, 'RESOURCE_UNAVAILABLE', 'Blackmarket ist deaktiviert.', nil, nil, nil)
    end

    return exports.nexa_illegal_core['illegal.blackmarketSell'](source, payload, NexaBlackmarketServer.catalog)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    exports.nexa_logs:info(NEXA_BLACKMARKET.resourceName, 'Blackmarket gestartet.', {
        version = NEXA_BLACKMARKET.version,
        featureFlag = NexaBlackmarketConfig.featureFlag
    })
end)

exports('getStatus', getStatus)
exports('blackmarket.getCatalog', getCatalog)
exports('blackmarket.buy', buy)
exports('blackmarket.sell', sell)
