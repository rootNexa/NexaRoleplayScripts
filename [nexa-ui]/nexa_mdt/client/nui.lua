RegisterNUICallback(NEXA_MDT_NUI.ready, function(_, cb)
    cb({
        success = true
    })
end)

RegisterNUICallback(NEXA_MDT_NUI.close, function(_, cb)
    exports.nexa_mdt:close()
    cb({
        success = true
    })
end)

RegisterNUICallback(NEXA_MDT_NUI.refresh, function(_, cb)
    local refreshed = exports.nexa_mdt:refresh()
    cb({
        success = refreshed
    })
end)

RegisterNUICallback(NEXA_MDT_NUI.searchPerson, function(data, cb)
    local searched = exports.nexa_mdt:searchPerson(data or {})
    cb({
        success = searched
    })
end)
