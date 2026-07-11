RegisterNUICallback('adminClose', function(_, cb)
    CloseNexaAdminUi()
    cb({ ok = true })
end)

RegisterNUICallback('adminRefresh', function(_, cb)
    RefreshNexaAdminUi()
    cb({ ok = true })
end)

RegisterNUICallback('adminSection', function(data, cb)
    if type(data) == 'table' and type(data.section) == 'string' then
        OpenNexaAdminUi(data.section)
    end

    cb({ ok = true })
end)
