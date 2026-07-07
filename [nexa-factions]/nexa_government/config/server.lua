NexaGovernmentServer = {
    memberLimit = 20,
    maxDocumentDataLength = 1000,
    maxReasonLength = 128,
    maxInvoiceAmount = NexaGovernmentConfig.maxInvoiceAmount,
    permissions = {
        duty = 'faction.duty.toggle',
        ownCallsign = 'faction.callsign.self',
        manageCallsign = 'faction.callsign.manage',
        viewMembers = 'faction.members.view',
        documentsIssue = 'government.documents.issue',
        documentsRevoke = 'government.documents.revoke',
        licensesIssue = 'government.licenses.issue',
        licensesRevoke = 'government.licenses.revoke',
        feesCreate = 'government.fees.create'
    }
}
