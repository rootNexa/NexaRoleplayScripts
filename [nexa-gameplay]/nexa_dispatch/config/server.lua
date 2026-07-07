NexaDispatchServer = {
    allowedCategories = {
        general = true,
        emergency = true,
        police = true,
        medical = true,
        fire = true,
        traffic = true
    },
    allowedFactions = {
        lspd = true,
        ems = true,
        government = true,
        weazel = true
    },
    statusTransitions = {
        open = {
            assigned = true,
            closed = true,
            cancelled = true
        },
        assigned = {
            open = true,
            closed = true,
            cancelled = true
        },
        closed = {},
        cancelled = {}
    }
}
