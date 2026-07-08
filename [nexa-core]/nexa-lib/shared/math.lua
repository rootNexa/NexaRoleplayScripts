NexaLib.Math = NexaLib.Math or {}

function NexaLib.Math.clamp(value, min, max)
    value = tonumber(value)
    min = tonumber(min)
    max = tonumber(max)

    if not value or not min or not max then
        return nil
    end

    if value < min then
        return min
    end

    if value > max then
        return max
    end

    return value
end

function NexaLib.Math.round(value, decimals)
    value = tonumber(value)
    decimals = tonumber(decimals) or 0

    if not value then
        return nil
    end

    local multiplier = 10 ^ decimals
    return math.floor(value * multiplier + 0.5) / multiplier
end
