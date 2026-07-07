local replayEntries = {}
local replayCount = 0
local secureInternalDispatch = false

function NexaAnticheatIsDeniedEvent(eventName)
    return NexaAnticheatServer.eventDenylist[eventName] == true
end

function NexaAnticheatIsAllowedEvent(eventName)
    if NexaAnticheatServer.eventAllowlist[eventName] == true then
        return true
    end

    return false
end

local function normalizeResourceName(resourceName)
    if type(resourceName) ~= 'string' or resourceName == '' or #resourceName > 64 then
        return nil
    end

    if not resourceName:match('^[%w_%-]+$') then
        return nil
    end

    return resourceName
end

function NexaAnticheatValidateCallingResource(registered, context)
    context = context or {}

    local resourceName = normalizeResourceName(context.resourceName or GetInvokingResource() or registered.registeredBy)

    if resourceName == nil then
        return false, 'INVALID_RESOURCE'
    end

    if GetResourceState(resourceName) == 'missing' then
        return false, 'RESOURCE_UNAVAILABLE'
    end

    if registered.allowedResources ~= nil and next(registered.allowedResources) ~= nil and registered.allowedResources[resourceName] ~= true then
        return false, 'RESOURCE_NOT_ALLOWED'
    end

    return true, 'OK', resourceName
end

local function getReplayKey(source, eventName, requestId)
    return ('%s:%s:%s'):format(tostring(source), eventName, requestId)
end

local function purgeReplayEntries(now)
    local removed = 0

    for key, entry in pairs(replayEntries) do
        if now - entry.createdAt >= NexaAnticheatServer.replayProtection.windowSeconds then
            replayEntries[key] = nil
            removed = removed + 1
        end
    end

    replayCount = math.max(0, replayCount - removed)
end

function NexaAnticheatValidateReplay(source, eventName, payload)
    if type(payload) ~= 'table' then
        return false, 'INVALID_PAYLOAD'
    end

    local requestId = payload.requestId or payload.request_id or payload.nonce

    if type(requestId) ~= 'string' or requestId == '' or #requestId > 64 then
        return false, 'REPLAY_TOKEN_REQUIRED'
    end

    if not requestId:match('^[%w%._:%-]+$') then
        return false, 'INVALID_REPLAY_TOKEN'
    end

    local now = os.time()
    local replayKey = getReplayKey(source, eventName, requestId)

    purgeReplayEntries(now)

    if replayEntries[replayKey] ~= nil then
        return false, 'REPLAY_DETECTED'
    end

    if replayCount >= NexaAnticheatServer.replayProtection.maxEntries then
        return false, 'REPLAY_CACHE_FULL'
    end

    replayEntries[replayKey] = {
        source = source,
        eventName = eventName,
        requestId = requestId,
        createdAt = now
    }
    replayCount = replayCount + 1

    return true, 'OK', requestId
end

function NexaAnticheatEmitSecureInternalEvent(eventName, metadata)
    if NexaAnticheatServer.secureInternalEvents[eventName] ~= true then
        return false, 'INTERNAL_EVENT_NOT_ALLOWED'
    end

    secureInternalDispatch = true
    TriggerEvent(eventName, metadata or {})
    secureInternalDispatch = false

    return true, 'OK'
end

function NexaAnticheatIsSecureInternalDispatch()
    return secureInternalDispatch == true
end
