NexaMdtConfig = {
    locale = 'de',
    designSystemResource = 'nexa_ui',
    defaultMdtType = 'police',
    snapshotCallback = 'nexa:mdt:cb:getSnapshot',
    personSearchCallback = 'nexa:mdt:cb:searchPerson'
}

MDT_TYPES = {
    police = 'police',
    ems = 'ems',
    government = 'government',
    gang = 'gang',
    business = 'business',
    media = 'media'
}

MDT_TYPE_MODULES = {
    police = {
        'persons',
        'vehicles',
        'warrants',
        'reports',
        'dispatch'
    },
    ems = {
        'patients',
        'treatments',
        'dispatch'
    },
    government = {
        'documents',
        'licenses',
        'fees'
    },
    gang = {
        'members',
        'territories',
        'reputation'
    },
    business = {
        'employees',
        'invoices',
        'documents'
    },
    media = {
        'reports',
        'press'
    }
}

MDT_MODULE_LABELS = {
    overview = 'Uebersicht',
    persons = 'Personen',
    vehicles = 'Fahrzeuge',
    warrants = 'Haftbefehle',
    reports = 'Berichte',
    dispatch = 'Einsaetze',
    patients = 'Patienten',
    treatments = 'Behandlungen',
    documents = 'Dokumente',
    licenses = 'Lizenzen',
    fees = 'Gebuehren',
    members = 'Mitglieder',
    territories = 'Gebiete',
    reputation = 'Reputation',
    employees = 'Mitarbeiter',
    invoices = 'Rechnungen',
    press = 'Presse'
}
