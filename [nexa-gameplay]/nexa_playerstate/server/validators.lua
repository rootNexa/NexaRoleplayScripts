function NexaPlayerStateNormalizeSource(value)
    local source = tonumber(value)
    return source and source > 0 and math.floor(source) or nil
end

function NexaPlayerStateNormalizeId(value)
    local id = tonumber(value)
    return id and id > 0 and math.floor(id) or nil
end

function NexaPlayerStateNormalizeBucket(value)
    local bucket = tonumber(value)

    if not bucket or bucket < 0 or bucket > 2147483647 then
        return nil
    end

    return math.floor(bucket)
end

function NexaPlayerStateNormalizeCoords(value)
    if type(value) ~= 'table' then
        return nil
    end

    local x = tonumber(value.x)
    local y = tonumber(value.y)
    local z = tonumber(value.z)
    local heading = tonumber(value.heading or 0.0)
    local max = NexaPlayerStateConfig.maxCoordinate

    if not x or not y or not z or not heading then
        return nil
    end

    if x ~= x or y ~= y or z ~= z or heading ~= heading then
        return nil
    end

    if math.abs(x) > max or math.abs(y) > max or math.abs(z) > max then
        return nil
    end

    return {
        x = x,
        y = y,
        z = z,
        heading = heading,
        bucket = NexaPlayerStateNormalizeBucket(value.bucket) or NexaPlayerStateConfig.defaultBucket
    }
end

function NexaPlayerStateDistance(left, right)
    if type(left) ~= 'table' or type(right) ~= 'table' then
        return nil
    end

    local dx = (left.x or 0.0) - (right.x or 0.0)
    local dy = (left.y or 0.0) - (right.y or 0.0)
    local dz = (left.z or 0.0) - (right.z or 0.0)
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end
