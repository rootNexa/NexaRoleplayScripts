RegisterNUICallback(NEXA_PHONE_NUI.ready, function(_, cb)
    cb({
        success = true
    })
end)

RegisterNUICallback(NEXA_PHONE_NUI.close, function(_, cb)
    exports.nexa_phone:close()
    cb({
        success = true
    })
end)

RegisterNUICallback(NEXA_PHONE_NUI.refresh, function(_, cb)
    local refreshed = exports.nexa_phone:refresh()
    cb({
        success = refreshed
    })
end)

RegisterNUICallback(NEXA_PHONE_NUI.saveNote, function(data, cb)
    local saved = exports.nexa_phone:saveNote(data or {})
    cb({
        success = saved
    })
end)

RegisterNUICallback(NEXA_PHONE_NUI.sendMessage, function(data, cb)
    local sent = exports.nexa_phone:sendMessage(data or {})
    cb({
        success = sent
    })
end)
