local function handleTransition(source, eventName, payload, transition)
    if not exports.nexa_security:validateSource(source) then
        return
    end

    local rateLimit = exports.nexa_security:checkRateLimit(source, eventName)

    if not rateLimit.success then
        return
    end

    payload = payload or {}
    payload.transition = transition

    exports.nexa_zones['zones.reportTransition'](source, payload)
end

RegisterNetEvent(NEXA_ZONES_EVENTS.entered, function(payload)
    handleTransition(source, NEXA_ZONES_EVENTS.entered, payload, 'entered')
end)

RegisterNetEvent(NEXA_ZONES_EVENTS.left, function(payload)
    handleTransition(source, NEXA_ZONES_EVENTS.left, payload, 'left')
end)
