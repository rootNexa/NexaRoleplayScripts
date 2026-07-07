NexaApiContracts['anticheat.registerSecureEvent'] = {
    name = 'anticheat.registerSecureEvent',
    module = 'anticheat',
    purpose = 'Kritisches Serverevent in der Secure Event Registry registrieren.',
    status = 'active',
    allowedCallers = { 'nexa-core' },
    input = { 'eventName', 'options' },
    output = 'standard_response',
    errors = { 'INVALID_INPUT', 'INVALID_EVENT_NAME', 'EVENT_DENIED', 'EVENT_NOT_ALLOWED', 'EVENT_ALREADY_REGISTERED' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['anticheat.validateEvent'] = {
    name = 'anticheat.validateEvent',
    module = 'anticheat',
    purpose = 'Kritisches Event serverseitig gegen Registry, Allowlist, Denylist, Session, Resource, Token, Replay-Schutz, Payload und Rate Limit validieren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-gameplay', 'nexa-ui', 'nexa-factions', 'nexa-vehicles', 'nexa-housing', 'nexa-criminal', 'nexa-world', 'nexa-admin' },
    input = { 'source', 'eventName', 'payload', 'token' },
    output = 'standard_response',
    errors = { 'INVALID_SOURCE', 'INVALID_EVENT_NAME', 'EVENT_DENIED', 'EVENT_NOT_ALLOWED', 'EVENT_NOT_REGISTERED', 'INVALID_PAYLOAD', 'INVALID_PAYLOAD_TYPE', 'PAYLOAD_TOO_LARGE', 'PAYLOAD_FIELD_NOT_ALLOWED', 'RESOURCE_NOT_ALLOWED', 'TOKEN_REQUIRED', 'INVALID_TOKEN', 'TOKEN_EXPIRED', 'TOKEN_SCOPE_MISMATCH', 'REPLAY_TOKEN_REQUIRED', 'REPLAY_DETECTED', 'SESSION_NOT_FOUND', 'RATE_LIMITED' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['anticheat.listSecureEvents'] = {
    name = 'anticheat.listSecureEvents',
    module = 'anticheat',
    purpose = 'Registrierte Secure Events fuer serverseitige Audits und Devtools lesen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = {},
    output = 'standard_response',
    errors = {},
    permissions = {},
    audit = false,
    rateLimit = false
}

NexaApiContracts['anticheat.issueToken'] = {
    name = 'anticheat.issueToken',
    module = 'anticheat',
    purpose = 'Kurzlebigen serverseitigen Token fuer ein registriertes Event ausstellen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-gameplay', 'nexa-ui', 'nexa-factions', 'nexa-vehicles', 'nexa-housing', 'nexa-criminal', 'nexa-world', 'nexa-admin' },
    input = { 'source', 'eventName', 'metadata?' },
    output = 'standard_response',
    errors = { 'INVALID_SOURCE', 'INVALID_EVENT_NAME', 'RATE_LIMITED' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['anticheat.verifyToken'] = {
    name = 'anticheat.verifyToken',
    module = 'anticheat',
    purpose = 'Event-Token serverseitig gegen Source und Event-Scope verifizieren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-gameplay', 'nexa-ui', 'nexa-factions', 'nexa-vehicles', 'nexa-housing', 'nexa-criminal', 'nexa-world', 'nexa-admin' },
    input = { 'source', 'eventName', 'token' },
    output = 'standard_response',
    errors = { 'INVALID_SOURCE', 'INVALID_EVENT_NAME', 'TOKEN_REQUIRED', 'INVALID_TOKEN', 'TOKEN_EXPIRED', 'TOKEN_SCOPE_MISMATCH', 'RATE_LIMITED' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['anticheat.validateSession'] = {
    name = 'anticheat.validateSession',
    module = 'anticheat',
    purpose = 'Spielersession serverseitig validieren.',
    status = 'active',
    allowedCallers = { 'nexa-core' },
    input = { 'source' },
    output = 'standard_response',
    errors = { 'INVALID_SOURCE', 'SESSION_NOT_FOUND' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['anticheat.validateResourceIntegrity'] = {
    name = 'anticheat.validateResourceIntegrity',
    module = 'anticheat',
    purpose = 'Registrierte Core-Resources gegen erwartete Runtime-Zustaende pruefen.',
    status = 'active',
    allowedCallers = { 'nexa-core' },
    input = { 'resourceName?' },
    output = 'standard_response',
    errors = { 'INVALID_INPUT', 'RESOURCE_NOT_REGISTERED', 'RESOURCE_INTEGRITY_FAILED' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['money.validateIntegrity'] = {
    name = 'money.validateIntegrity',
    module = 'money',
    purpose = 'Read-only Money-Integrity-Checks fuer Kontostaende, Ledger, Duplikate, Cooldowns und unautorisierte Ledger-Resources ausfuehren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'limit?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'DATABASE_ERROR' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['money.validateAccountBalance'] = {
    name = 'money.validateAccountBalance',
    module = 'money',
    purpose = 'Kontostand read-only gegen negative Werte und Overflow pruefen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'accountId' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_INPUT', 'NOT_FOUND' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['money.validateEconomyLedger'] = {
    name = 'money.validateEconomyLedger',
    module = 'money',
    purpose = 'Economy-Ledger-Eintrag read-only auf Betrag, Kontoreferenz und Duplikate pruefen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'transactionId' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_INPUT', 'NOT_FOUND' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['money.getReconciliationReport'] = {
    name = 'money.getReconciliationReport',
    module = 'money',
    purpose = 'Read-only Reconciliation Report fuer Money Protection erzeugen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'limit?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'DATABASE_ERROR' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['inventory.validateIntegrity'] = {
    name = 'inventory.validateIntegrity',
    module = 'inventory',
    purpose = 'Read-only Inventory Integrity Checks fuer Item-Ledger, Duplikate, auffaellige Bewegungen, unautorisierte Item-Resources, unmoegliche Stash-Zugriffe und High-Risk-Items ausfuehren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'limit?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'DATABASE_ERROR' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['inventory.validateOxAccess'] = {
    name = 'inventory.validateOxAccess',
    module = 'inventory',
    purpose = 'ox_inventory Zugriff read-only gegen Resource-Status, Session und Stash-Registry validieren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'source?', 'stashName?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_INPUT', 'RESOURCE_UNAVAILABLE', 'SESSION_NOT_FOUND', 'DATABASE_ERROR' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['inventory.validateItemLedger'] = {
    name = 'inventory.validateItemLedger',
    module = 'inventory',
    purpose = 'Item-Ledger-Eintrag read-only auf Event-ID, Itemname, Menge und autorisierte Resource pruefen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'eventId' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_INPUT', 'NOT_FOUND', 'DATABASE_ERROR' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['inventory.getReconciliationReport'] = {
    name = 'inventory.getReconciliationReport',
    module = 'inventory',
    purpose = 'Read-only Reconciliation Report fuer Inventory Protection erzeugen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'limit?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'DATABASE_ERROR' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['vehicle.validateIntegrity'] = {
    name = 'vehicle.validateIntegrity',
    module = 'vehicle',
    purpose = 'Read-only Vehicle Integrity Checks fuer Besitz, Garage, Duplikate, Spawn-, Lock-, Fuel-, Impound-, Dealer- und Key-Muster ausfuehren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'limit?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'DATABASE_ERROR' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['vehicle.validateOwnership'] = {
    name = 'vehicle.validateOwnership',
    module = 'vehicle',
    purpose = 'Fahrzeugbesitz read-only gegen serverseitige Character-Zuordnung validieren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'vehicleId' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_INPUT', 'NOT_FOUND', 'DATABASE_ERROR' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['vehicle.validateGarageState'] = {
    name = 'vehicle.validateGarageState',
    module = 'vehicle',
    purpose = 'Garage-State read-only gegen Fahrzeugstatus, Garage und Impound-Seized-Zustaende validieren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'vehicleId' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_INPUT', 'NOT_FOUND', 'DATABASE_ERROR' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['vehicle.validateHistory'] = {
    name = 'vehicle.validateHistory',
    module = 'vehicle',
    purpose = 'Vehicle-History read-only gegen autorisierte serverseitige Eventtypen pruefen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'vehicleId', 'limit?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_INPUT', 'DATABASE_ERROR' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['vehicle.getReconciliationReport'] = {
    name = 'vehicle.getReconciliationReport',
    module = 'vehicle',
    purpose = 'Read-only Reconciliation Report fuer Vehicle Protection erzeugen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'limit?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'DATABASE_ERROR' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['teleport.validatePositionSnapshot'] = {
    name = 'teleport.validatePositionSnapshot',
    module = 'anticheat',
    purpose = 'Serverseitige Position Snapshot Validation fuer Teleport Detection ausfuehren; Client-Koordinaten werden nicht als Wahrheit verwendet.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin', 'nexa-world', 'nexa-vehicles', 'nexa-housing' },
    input = { 'source', 'payload?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'RATE_LIMITED', 'PED_NOT_FOUND', 'POSITION_UNAVAILABLE' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['teleport.allow'] = {
    name = 'teleport.allow',
    module = 'anticheat',
    purpose = 'Legitimen serverseitigen Teleport-Kontext fuer Spawn, Garage, Interior, Housing oder Admin-Utility kurzlebig whitelisten.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin', 'nexa-world', 'nexa-vehicles', 'nexa-housing' },
    input = { 'source', 'context', 'metadata?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'INVALID_INPUT', 'NO_PERMISSION' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['teleport.getSuspiciousReports'] = {
    name = 'teleport.getSuspiciousReports',
    module = 'anticheat',
    purpose = 'Suspicious movement reports read-only fuer Audit, Logging und Admin-Auswertung lesen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'limit?' },
    output = 'standard_response',
    errors = {},
    permissions = {},
    audit = false,
    rateLimit = false
}

NexaApiContracts['noclip.validateMovement'] = {
    name = 'noclip.validateMovement',
    module = 'anticheat',
    purpose = 'Noclip Detection serverseitig ueber Movement Plausibility Checks, Ground/Contact Validation und legitime Movement-Ausnahmen ausfuehren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin', 'nexa-world', 'nexa-vehicles', 'nexa-housing' },
    input = { 'source', 'payload?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'RATE_LIMITED', 'PED_NOT_FOUND', 'POSITION_UNAVAILABLE' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['noclip.allowException'] = {
    name = 'noclip.allowException',
    module = 'anticheat',
    purpose = 'Legitime Interior-, Housing-, Garage-, Spawn- oder Admin-Noclip-Ausnahme kurzlebig serverseitig markieren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin', 'nexa-world', 'nexa-vehicles', 'nexa-housing' },
    input = { 'source', 'context', 'metadata?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'INVALID_INPUT', 'NO_PERMISSION' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['noclip.getSuspiciousReports'] = {
    name = 'noclip.getSuspiciousReports',
    module = 'anticheat',
    purpose = 'Suspicious noclip reports read-only fuer Audit, Logging und Admin-Auswertung lesen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'limit?' },
    output = 'standard_response',
    errors = {},
    permissions = {},
    audit = false,
    rateLimit = false
}

NexaApiContracts['godmode.validateState'] = {
    name = 'godmode.validateState',
    module = 'anticheat',
    purpose = 'Godmode Detection serverseitig ueber Health/Armor Plausibility, Damage Event Validation und Invulnerability State Detection ausfuehren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin', 'nexa-gameplay', 'nexa_admin', 'nexa_ems', 'nexa_identity' },
    input = { 'source', 'payload?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'RATE_LIMITED', 'PED_NOT_FOUND', 'HEALTH_UNAVAILABLE' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['godmode.allowException'] = {
    name = 'godmode.allowException',
    module = 'anticheat',
    purpose = 'Legitime Heal-, Revive-, EMS-Treatment-, Spawn-Protection- oder Admin-Ausnahme kurzlebig serverseitig markieren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin', 'nexa-gameplay', 'nexa_admin', 'nexa_ems', 'nexa_identity' },
    input = { 'source', 'context', 'metadata?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'INVALID_INPUT', 'NO_PERMISSION' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['godmode.recordDamageEvent'] = {
    name = 'godmode.recordDamageEvent',
    module = 'anticheat',
    purpose = 'Serverseitiges Damage-Event fuer Godmode Damage Event Validation vormerken.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin', 'nexa-gameplay', 'nexa-criminal', 'nexa-world', 'nexa_admin', 'nexa_ems', 'nexa_identity' },
    input = { 'source', 'amount', 'reason?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'INVALID_INPUT', 'RATE_LIMITED' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['godmode.getSuspiciousReports'] = {
    name = 'godmode.getSuspiciousReports',
    module = 'anticheat',
    purpose = 'Suspicious godmode reports read-only fuer Audit, Logging und Admin-Auswertung lesen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'limit?' },
    output = 'standard_response',
    errors = {},
    permissions = {},
    audit = false,
    rateLimit = false
}

NexaApiContracts['executor.validateSignal'] = {
    name = 'executor.validateSignal',
    module = 'anticheat',
    purpose = 'Executor / Injection Detection serverseitig ueber Event-Patterns, Resource-Patterns, Payload-Strukturen und konfigurierbare Exploit-Signaturen bewerten; Client-Tamper-Indikatoren sind untrusted Signals.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin', 'nexa-gameplay', 'nexa-ui', 'nexa-factions', 'nexa-vehicles', 'nexa-housing', 'nexa-criminal', 'nexa-world', 'nexa_anticheat', 'nexa_api', 'nexa_security', 'nexa_admin' },
    input = { 'source', 'payload' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'INVALID_INPUT', 'RATE_LIMITED' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['executor.getSuspiciousReports'] = {
    name = 'executor.getSuspiciousReports',
    module = 'anticheat',
    purpose = 'Suspicious executor reports read-only fuer Audit, Logging und Admin-Auswertung lesen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'limit?' },
    output = 'standard_response',
    errors = {},
    permissions = {},
    audit = false,
    rateLimit = false
}

NexaApiContracts['evidence.requestCapture'] = {
    name = 'evidence.requestCapture',
    module = 'anticheat',
    purpose = 'Screenshot/Evidence-Capture manuell, permission-geprueft und auditierbar als vorbereitete Request-Metadaten anfordern.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin', 'nexa_anticheat', 'nexa_api', 'nexa_admin' },
    input = { 'actorSource', 'targetSource', 'payload' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'INVALID_INPUT', 'NO_PERMISSION', 'RATE_LIMITED' },
    permissions = { 'admin.evidence.capture', 'admin.screenshot.request', 'anticheat.evidence.request' },
    audit = true,
    rateLimit = true
}

NexaApiContracts['evidence.prepareAnticheatCapture'] = {
    name = 'evidence.prepareAnticheatCapture',
    module = 'anticheat',
    purpose = 'Anticheat-Evidence-Capture nur als vorbereitete Schnittstelle ohne automatische Aufnahme, Upload oder Sanktion vormerken.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa_anticheat', 'nexa_api', 'nexa_security' },
    input = { 'targetSource', 'payload?' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'RESOURCE_NOT_ALLOWED', 'RATE_LIMITED' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['evidence.getCaptureRequests'] = {
    name = 'evidence.getCaptureRequests',
    module = 'anticheat',
    purpose = 'Evidence-Capture-Requests read-only fuer Audit, Logging und Admin-Auswertung lesen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin' },
    input = { 'limit?' },
    output = 'standard_response',
    errors = {},
    permissions = {},
    audit = false,
    rateLimit = false
}

NexaApiContracts['ban.createManual'] = {
    name = 'ban.createManual',
    module = 'anticheat',
    purpose = 'Manuellen temporaeren oder permanenten Ban permission-geprueft, identifier-verknuepft, auditierbar und ohne Anticheat-Automatik erstellen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin', 'nexa_anticheat', 'nexa_api', 'nexa_admin' },
    input = { 'actorSource', 'payload' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'INVALID_INPUT', 'INVALID_DURATION', 'PLAYER_NOT_FOUND', 'NO_PERMISSION', 'RATE_LIMITED' },
    permissions = { 'admin.ban', 'admin.ban.permanent', 'admin.ban.temporary', 'anticheat.ban.manual' },
    audit = true,
    rateLimit = true
}

NexaApiContracts['ban.checkSource'] = {
    name = 'ban.checkSource',
    module = 'anticheat',
    purpose = 'Ban-Pruefung beim Join ueber erlaubte FiveM-Identifier gegen bestehende Spieler-/Ban-Verknuepfung ausfuehren.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa_anticheat', 'nexa_api' },
    input = { 'source' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'IDENTIFIERS_UNAVAILABLE', 'RATE_LIMITED' },
    permissions = {},
    audit = true,
    rateLimit = true
}

NexaApiContracts['ban.getHistory'] = {
    name = 'ban.getHistory',
    module = 'anticheat',
    purpose = 'Ban-Historie read-only fuer Admin-/Security-Review inklusive vorbereiteter Appeal-/Review-Status-Struktur lesen.',
    status = 'active',
    allowedCallers = { 'nexa-core', 'nexa-admin', 'nexa_anticheat', 'nexa_api', 'nexa_admin' },
    input = { 'payload' },
    output = 'standard_response',
    errors = { 'FEATURE_DISABLED', 'INVALID_SOURCE', 'NO_PERMISSION', 'RATE_LIMITED' },
    permissions = { 'admin.ban.history', 'admin.ban', 'security.review' },
    audit = true,
    rateLimit = true
}
