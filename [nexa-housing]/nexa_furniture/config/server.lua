NexaFurnitureServerConfig = {
    maxPropertyUnitId = 2147483647,
    maxFurnitureId = 2147483647,
    maxModelLength = 64,
    maxLabelLength = 64,
    maxReasonLength = 128,
    callbackRateLimits = {
        load = 'nexa:furniture:cb:load',
        place = 'nexa:furniture:cb:place',
        save = 'nexa:furniture:cb:save',
        remove = 'nexa:furniture:cb:remove'
    }
}
