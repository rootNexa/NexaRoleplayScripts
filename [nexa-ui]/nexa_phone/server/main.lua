local migrated = false

CreateThread(function()
    migrated = NexaPhoneDatabase.Migrate() == true
    print(('[nexa_phone] bereit. migrated=%s'):format(tostring(migrated)))
end)

exports('getSchema', NexaPhoneDatabase.GetSchema)
exports('getStatus', function()
    return { resourceName = 'nexa_phone', migrated = migrated }
end)
