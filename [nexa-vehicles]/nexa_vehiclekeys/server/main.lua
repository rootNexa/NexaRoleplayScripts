CreateThread(function()
    if GetResourceState('nexa_api') == 'started' then
        exports.nexa_api['vehicle.cleanupExpiredKeys']()
    end

    lib.print.info('nexa_vehiclekeys bereit.')
end)
