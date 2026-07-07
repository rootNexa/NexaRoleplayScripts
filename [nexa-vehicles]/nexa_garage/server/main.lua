CreateThread(function()
    if GetResourceState('nexa_api') == 'started' then
        exports.nexa_api['vehicle.reconcileGarage']()
    end

    lib.print.info('nexa_garage bereit.')
end)
