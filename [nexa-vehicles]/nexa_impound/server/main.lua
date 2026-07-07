local vehicleLocks = {}

local function nowMs()
    return GetGameTimer()
end

function NexaImpoundAcquireVehicleLock(vehicleId, source)
    local key = tostring(vehicleId)
    local current = vehicleLocks[key]
    local currentTime = nowMs()

    if current ~= nil and current.expiresAt > currentTime then
        return false
    end

    vehicleLocks[key] = {
        source = source,
        expiresAt = currentTime + 15000
    }

    return true
end

function NexaImpoundReleaseVehicleLock(vehicleId, source)
    local key = tostring(vehicleId)
    local current = vehicleLocks[key]

    if current ~= nil and current.source == source then
        vehicleLocks[key] = nil
    end
end

CreateThread(function()
    while true do
        Wait(60000)

        local currentTime = nowMs()

        for key, lock in pairs(vehicleLocks) do
            if lock.expiresAt <= currentTime then
                vehicleLocks[key] = nil
            end
        end
    end
end)
