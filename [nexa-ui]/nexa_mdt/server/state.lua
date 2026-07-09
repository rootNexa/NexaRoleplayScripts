local function filterPersons(query)
    local text = NexaMdtLimitText(query, NexaMdtServerConfig.limits.maxQueryLength):lower()
    local persons = {}

    for _, person in ipairs(NexaMdtServerConfig.samplePersons) do
        local searchable = ((person.id or '') .. ' ' .. (person.name or '')):lower()

        if text == '' or searchable:find(text, 1, true) then
            persons[#persons + 1] = NexaMdtCopyTable(person)
        end

        if #persons >= NexaMdtServerConfig.limits.maxPersons then
            break
        end
    end

    return persons
end

function NexaMdtGetLocalSnapshot()
    return {
        persons = NexaMdtCopyTable(NexaMdtServerConfig.samplePersons),
        vehicles = NexaMdtCopyTable(NexaMdtServerConfig.sampleVehicles),
        records = NexaMdtCopyTable(NexaMdtServerConfig.sampleRecords),
        warrants = NexaMdtCopyTable(NexaMdtServerConfig.sampleWarrants),
        fines = NexaMdtCopyTable(NexaMdtServerConfig.sampleFines),
        reports = NexaMdtCopyTable(NexaMdtServerConfig.sampleReports),
        evidence = NexaMdtCopyTable(NexaMdtServerConfig.sampleEvidence),
        patients = {},
        treatments = {},
        documents = {},
        licenses = {},
        fees = {},
        members = {},
        territories = {},
        reputation = {},
        employees = {},
        invoices = {},
        press = {}
    }
end

function NexaMdtSearchPersons(query)
    return filterPersons(query)
end
