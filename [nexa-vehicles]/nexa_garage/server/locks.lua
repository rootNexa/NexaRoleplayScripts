local locks = {}

local function now()
    return GetGameTimer()
end

function NexaGarageAcquireLock(vehicleId, source)
    local key = tostring(vehicleId)
    local existing = locks[key]
    local current = now()

    if existing ~= nil and existing.expiresAt > current then
        return false
    end

    locks[key] = {
        source = source,
        expiresAt = current + NexaGarageServerConfig.lockTtlMs
    }

    return true
end

function NexaGarageReleaseLock(vehicleId, source)
    local key = tostring(vehicleId)
    local existing = locks[key]

    if existing == nil then
        return
    end

    if source == nil or existing.source == source then
        locks[key] = nil
    end
end
