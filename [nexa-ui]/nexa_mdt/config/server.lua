NexaMdtServerConfig = {
    callbacks = {
        snapshot = 'nexa:mdt:cb:getSnapshot',
        personSearch = 'nexa:mdt:cb:searchPerson'
    },
    permissions = {
        view = 'police.mdt.view',
        records = 'police.mdt.records',
        warrants = 'police.mdt.warrants',
        fines = 'police.mdt.fines',
        reports = 'police.mdt.reports',
        dispatch = 'dispatch.view'
    },
    limits = {
        maxQueryLength = 48,
        maxPersons = 8,
        maxRecords = 8,
        maxWarrants = 8,
        maxFines = 8,
        maxReports = 8,
        maxDispatch = 10
    },
    samplePersons = {
        {
            id = 'person-001',
            name = 'Mika Berger',
            dateOfBirth = '1994-03-18',
            note = 'Buergerakte, vorbereitete Ansicht'
        },
        {
            id = 'person-002',
            name = 'Lea Sommer',
            dateOfBirth = '1988-11-02',
            note = 'Buergerakte, vorbereitete Ansicht'
        }
    },
    sampleVehicles = {
        {
            id = 'vehicle-001',
            plate = 'SA 2041',
            model = 'Kompaktklasse',
            status = 'Read-only Platzhalter'
        }
    },
    sampleRecords = {
        {
            id = 'record-001',
            title = 'Aktennotiz',
            summary = 'Vorbereitete Aktenuebersicht ohne Fallentscheidung.',
            status = 'offen'
        }
    },
    sampleWarrants = {
        {
            id = 'warrant-001',
            title = 'Pruefvermerk',
            subject = 'Mika Berger',
            status = 'Entwurf'
        }
    },
    sampleFines = {
        {
            id = 'fine-001',
            title = 'Gebuehrenvermerk',
            amount = '0',
            status = 'Anzeige'
        }
    },
    sampleReports = {
        {
            id = 'report-001',
            title = 'Einsatzbericht',
            summary = 'Workflow-Platzhalter fuer spaetere Berichte.',
            status = 'vorbereitet'
        }
    },
    sampleEvidence = {
        {
            id = 'evidence-001',
            title = 'Beweisuebersicht',
            summary = 'Read-only Struktur, kein Evidence-Gameplay.',
            status = 'vorbereitet'
        }
    }
}
