NexaBlackmarketConfig = {
    featureFlag = 'phase9b.blackmarket',
    categories = {
        tools = 'Werkzeuge',
        parts = 'Teile',
        documents = 'Dokumente'
    },
    dealers = {
        {
            dealerId = 'vespucci_broker',
            label = 'Vespucci Kontakt',
            categories = { 'tools', 'parts' }
        },
        {
            dealerId = 'sandy_runner',
            label = 'Sandy Runner',
            categories = { 'tools', 'documents' }
        }
    }
}
