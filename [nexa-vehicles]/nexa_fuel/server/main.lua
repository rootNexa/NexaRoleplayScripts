local purchaseLocks = {}

local function nowMs()
    return GetGameTimer()
end

function NexaFuelAcquirePurchaseLock(source, stationId, vehicleId)
    local key = tostring(vehicleId)
    local current = purchaseLocks[key]
    local currentTime = nowMs()

    if current ~= nil and current.expiresAt > currentTime then
        return false
    end

    purchaseLocks[key] = {
        source = source,
        expiresAt = currentTime + 15000
    }

    return true
end

function NexaFuelReleasePurchaseLock(source, stationId, vehicleId)
    local key = tostring(vehicleId)
    local current = purchaseLocks[key]

    if current ~= nil and current.source == source then
        purchaseLocks[key] = nil
    end
end

CreateThread(function()
    while true do
        Wait(60000)

        local currentTime = nowMs()

        for key, lock in pairs(purchaseLocks) do
            if lock.expiresAt <= currentTime then
                purchaseLocks[key] = nil
            end
        end
    end
end)
