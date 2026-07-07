NexaEmsServer = {
    memberLimit = 20,
    recordLimit = 10,
    maxSummaryLength = 500,
    maxTreatmentNotesLength = 500,
    maxInvoiceReasonLength = 128,
    maxInvoiceAmount = NexaEmsConfig.maxInvoiceAmount,
    permissions = {
        duty = 'faction.duty.toggle',
        ownCallsign = 'faction.callsign.self',
        manageCallsign = 'faction.callsign.manage',
        viewMembers = 'faction.members.view',
        recordsView = 'ems.records.view',
        recordsCreate = 'ems.records.create',
        treatmentCreate = 'ems.treatments.create',
        billingCreate = 'ems.billing.create'
    }
}
