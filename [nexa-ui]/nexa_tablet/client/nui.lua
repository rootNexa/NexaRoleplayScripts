RegisterNUICallback(NEXA_TABLET_NUI.ready, function(_, cb)
    cb({
        success = true
    })
end)

RegisterNUICallback(NEXA_TABLET_NUI.close, function(_, cb)
    exports.nexa_tablet:close()
    cb({
        success = true
    })
end)

RegisterNUICallback(NEXA_TABLET_NUI.refresh, function(_, cb)
    local refreshed = exports.nexa_tablet:refreshApps()
    cb({
        success = refreshed
    })
end)

RegisterNUICallback(NEXA_TABLET_NUI.openApp, function(_, cb)
    exports.nexa_tablet:notifyUnavailable()
    cb({
        success = false,
        code = 'APP_DISABLED'
    })
end)
