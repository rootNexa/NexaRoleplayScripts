NexaWeazelServer = {
    memberLimit = 20,
    maxAnnouncementTitleLength = NexaWeazelConfig.maxAnnouncementTitleLength,
    maxAnnouncementBodyLength = NexaWeazelConfig.maxAnnouncementBodyLength,
    maxPressNoteLength = NexaWeazelConfig.maxPressNoteLength,
    permissions = {
        duty = 'faction.duty.toggle',
        ownCallsign = 'faction.callsign.self',
        manageCallsign = 'faction.callsign.manage',
        viewMembers = 'faction.members.view',
        pressPassIssue = 'weazel.press.issue',
        announcementCreate = 'weazel.announcement.create'
    }
}
