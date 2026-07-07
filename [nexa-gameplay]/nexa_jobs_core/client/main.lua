RegisterNetEvent(NEXA_JOBS_EVENTS.requestResult, function(response)
    if response == nil or response.message == nil then
        return
    end

    lib.notify({
        title = 'Job',
        description = response.message,
        type = response.success and 'success' or 'error'
    })
end)

RegisterCommand('nexajob', function()
    if not NexaJobsClient.enableOxContext then
        return
    end

    lib.registerContext({
        id = 'nexa_jobs_core_menu',
        title = 'Job',
        options = {
            {
                title = 'Dienst umschalten',
                serverEvent = NEXA_JOBS_EVENTS.requestToggleDuty
            },
            {
                title = 'Gehalt anfordern',
                serverEvent = NEXA_JOBS_EVENTS.requestSalary
            }
        }
    })

    lib.showContext('nexa_jobs_core_menu')
end, false)
