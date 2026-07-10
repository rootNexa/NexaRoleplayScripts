NexaPhoneServerConfig = {
    callbacks = {
        snapshot = 'nexa:phone:cb:getSnapshot',
        saveNote = 'nexa:phone:cb:saveNote',
        sendMessage = 'nexa:phone:cb:sendMessage',
        addContact = 'nexa:phone:cb:addContact',
        addGroup = 'nexa:phone:cb:addGroup',
        logCall = 'nexa:phone:cb:logCall',
        savePreferences = 'nexa:phone:cb:savePreferences',
        emergencyCall = 'nexa:phone:cb:emergencyCall'
    },
    limits = {
        maxContacts = 12,
        maxMessages = 30,
        maxCalls = 12,
        maxNotes = 12,
        maxMails = 10,
        maxTitleLength = 48,
        maxBodyLength = 280,
        maxMessageLength = 180,
        maxRecipientLength = 48
    },
    defaultContacts = {
        {
            id = 'city-service',
            name = 'Stadtservice',
            number = '555-0100',
            note = 'Allgemeine Auskunft'
        },
        {
            id = 'cab-office',
            name = 'Fahrdienst-Zentrale',
            number = '555-0130',
            note = 'Nur Kontaktkarte'
        }
    },
    defaultCalls = {
        {
            id = 'call-welcome',
            label = 'Stadtservice',
            number = '555-0100',
            direction = 'eingehend',
            time = 'Heute'
        }
    },
    defaultMails = {
        {
            id = 'mail-welcome',
            sender = 'Stadtservice',
            subject = 'Willkommen in der Stadt',
            preview = 'Dein Telefon ist eingerichtet. Weitere Dienste folgen spaeter.'
        }
    }
}
