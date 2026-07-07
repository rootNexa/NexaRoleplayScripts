# nexa_anticheat

Phase 12A stellt den Anticheat-Core bereit. Phase 12B erweitert ihn um Event Protection: Secure Event Registry, Event-Allowlist, Event-Denylist, Payload-Validation, Payload-Size-Validation, Payload-Type-Validation, Source-Validation, Resource-Validation, Event-Rate-Limits, Replay-Protection, Token-Verification, sichere interne Events, Audit, Logging und API-Contracts. Phase 12C ergaenzt read-only Money Protection: Money Integrity Checks, Account-Balance-Validation, Economy-Ledger-Validation, Suspicious Transaction Detection, Duplicate Payout Detection, Negative Amount Detection, Overflow-/Underflow-Detection, Unauthorized Money Mutation Detection, Payout-Cooldown-Checks und Reconciliation Reports. Phase 12D ergaenzt read-only Inventory Protection: Inventory Integrity Checks, ox_inventory Access Validation, suspicious Item Movement Detection, Duplicate Item Detection, Unauthorized Item Mutation Detection, Negative Item Amount Detection, Impossible Stash Access Detection, Item-Ledger-Validation, High-Risk-Item-Monitoring, Audit, Logging und API-Contracts. Phase 12E ergaenzt read-only Vehicle Protection: Vehicle Integrity Checks, vehicle ownership validation, garage state validation, duplicate vehicle detection, unauthorized vehicle spawn detection, unauthorized lock/unlock detection, fuel manipulation detection, impound state validation, vehicle dealer purchase validation, vehicle key abuse detection, Audit, Logging und API-Contracts. Phase 12F ergaenzt Teleport Detection: Position Snapshot Validation, Distance Delta Checks, Speed/Movement Plausibility, Whitelist fuer legitime Teleports, Admin-Teleport-Ausnahmen, Spawn-/Garage-/Interior-/Housing-Ausnahmen, suspicious movement reports, Audit, Logging und API-Contracts. Phase 12G ergaenzt Noclip Detection: movement plausibility checks, ground/contact validation, vehicle/passenger exceptions, fall/jump/parachute exceptions, admin noclip exception, interior/housing/garage transition exceptions, suspicious noclip reports, Audit, Logging und API-Contracts. Phase 12H ergaenzt Godmode Detection: health/armor plausibility checks, damage event validation, invulnerability state detection, revive/heal/admin exceptions, EMS-treatment exceptions, spawn protection exceptions, suspicious godmode reports, Audit, Logging und API-Contracts. Phase 12I ergaenzt Executor / Injection Detection als serverseitige Verdachtslogik: verdaechtige Event-Patterns, Resource-Patterns, ungewoehnliche Payload-Strukturen, konfigurierbare Exploit-Signaturen, Client-Tamper-Indikatoren nur als untrusted Signals, suspicious executor reports, Audit, Logging und API-Contracts. Phase 12J ergaenzt Screenshot/Evidence-Capture-Grundstruktur: serverseitige Request-API, Permission-Pruefung, Audit, Logging, Rate-Limits, Evidence-Metadaten, manuelle Admin-Anforderung, Anticheat-Anforderung nur als vorbereitete Schnittstelle, Datenschutz-/Transparenz-Hinweise und API-Contracts. Phase 12K ergaenzt Ban-System-Grundstruktur: manuelle temporaere und permanente Bans, Ban-Gruende, Ban-Historie, Identifier-Verknuepfung, Ban-Pruefung beim Join, Appeal-/Review-Status als vorbereitete Struktur, Admin-Permissions, Audit, Logging, Rate-Limits und API-Contracts.

## Grenzen

- Zero Trust: Der Client ist niemals vertrauenswuerdig.
- Kritische Events muessen serverseitig registriert und validiert werden.
- Diese Resource fuehrt keine Gameplayaenderungen aus.
- Itemlogik bleibt bei `ox_inventory`; Nexa prueft nur Zugriff, Integritaet und verdaechtige Muster.
- Fahrzeugbesitz, Status, Fuel, Keys und Impound bleiben serverseitig; Nexa prueft nur Integritaet und verdaechtige Muster.
- Teleport Detection nutzt serverseitige Position Snapshots; legitime Spawn-, Garage-, Housing-, Interior- und Admin-Utility-Wechsel koennen serverseitig kurzlebig gewhitelistet werden.
- Noclip Detection nutzt serverseitige Entity-Bewegungsdaten und markiert nur wiederholte verdaechtige Luft-/Kontaktmuster; Springen, Fallen, Fahren, Beifahrer, Parachute und Transition-Kontexte bleiben ausgenommen.
- Godmode Detection nutzt serverseitige Health-/Armor-/Invulnerability-Zustaende und Damage-Events; legitimes Heilen, Revive, EMS-Behandlung, Spawn-Protection und Admin-Aktionen koennen serverseitig kurzlebig ausgenommen werden.
- Executor / Injection Detection nutzt ausschliesslich serverseitige Verdachtslogik und konfigurierbare Muster; Client-Tamper-Indikatoren sind niemals allein beweisend und bleiben untrusted Signals.
- Screenshot/Evidence Capture ist in Phase 12J nur eine permission-gepruefte, auditierbare und transparente Request-Grundstruktur; sie fuehrt keine heimlichen, dauerhaften oder automatischen Clientpruefungen aus.
- Ban-System-Aktionen sind in Phase 12K ausschliesslich manuell, permission-geprueft und auditierbar; Anticheat liefert nur Verdacht und erstellt keine automatischen Bans.
- Identifier-Verknuepfung nutzt nur erlaubte FiveM-Identifier aus `GetPlayerIdentifier`; Hardware-ID-, Endpoint-, Token- oder invasive Tracking-Methoden sind ausgeschlossen.
- Verdacht wird auditierbar markiert, aber nicht automatisch sanktioniert.
- Nicht enthalten: Executor, automatische Bans durch Anticheat, automatische Anticheat-Bans, Hardware-ID-/invasive Tracking-Systeme, externe Webpanel-Anbindung, Discord-Bot-Anbindung, automatische Massen-Screenshots, externe Upload-Anbindung ohne saubere Konfiguration, Client-Spyware, Kernel-/Systemzugriffe, invasive Clientpruefung, neue EMS-/Revive-Gameplay-Systeme, neue Fahrzeug-Gameplay-Systeme, neue Gameplay-Systeme, automatische Sanktionen.

## API

- `exports.nexa_anticheat:registerSecureEvent(eventName, options)`
- `exports.nexa_anticheat:listSecureEvents()`
- `exports.nexa_anticheat:validateEvent(source, eventName, payload, token)`
- `exports.nexa_anticheat:issueToken(source, eventName, metadata)`
- `exports.nexa_anticheat:validateToken(source, eventName, token)`
- `exports.nexa_anticheat:verifyEventToken(source, eventName, token)`
- `exports.nexa_anticheat:validateSession(source)`
- `exports.nexa_anticheat:validateResourceIntegrity(resourceName)`
- `exports.nexa_anticheat:validateMoneyIntegrity(payload)`
- `exports.nexa_anticheat:validateAccountBalance(payload)`
- `exports.nexa_anticheat:validateEconomyLedger(payload)`
- `exports.nexa_anticheat:getMoneyReconciliationReport(payload)`
- `exports.nexa_anticheat:validateInventoryIntegrity(payload)`
- `exports.nexa_anticheat:validateOxInventoryAccess(payload)`
- `exports.nexa_anticheat:validateItemLedger(payload)`
- `exports.nexa_anticheat:getInventoryReconciliationReport(payload)`
- `exports.nexa_anticheat:validateVehicleIntegrity(payload)`
- `exports.nexa_anticheat:validateVehicleOwnership(payload)`
- `exports.nexa_anticheat:validateVehicleGarageState(payload)`
- `exports.nexa_anticheat:validateVehicleHistory(payload)`
- `exports.nexa_anticheat:getVehicleReconciliationReport(payload)`
- `exports.nexa_anticheat:validatePositionSnapshot(source, payload)`
- `exports.nexa_anticheat:allowTeleport(source, context, metadata)`
- `exports.nexa_anticheat:getSuspiciousMovementReports(limit)`
- `exports.nexa_anticheat:validateNoclipMovement(source, payload)`
- `exports.nexa_anticheat:allowNoclipException(source, context, metadata)`
- `exports.nexa_anticheat:getSuspiciousNoclipReports(limit)`
- `exports.nexa_anticheat:validateGodmodeState(source, payload)`
- `exports.nexa_anticheat:allowGodmodeException(source, context, metadata)`
- `exports.nexa_anticheat:recordGodmodeDamageEvent(source, payload)`
- `exports.nexa_anticheat:getSuspiciousGodmodeReports(limit)`
- `exports.nexa_anticheat:validateExecutorSignal(source, payload)`
- `exports.nexa_anticheat:getSuspiciousExecutorReports(limit)`
- `exports.nexa_anticheat:requestEvidenceCapture(actorSource, targetSource, payload)`
- `exports.nexa_anticheat:prepareAnticheatEvidenceCapture(targetSource, payload)`
- `exports.nexa_anticheat:getEvidenceCaptureRequests(limit)`
- `exports.nexa_anticheat:createManualBan(actorSource, payload)`
- `exports.nexa_anticheat:checkBanForSource(source)`
- `exports.nexa_anticheat:getBanHistory(payload)`
- `exports.nexa_anticheat:getAuditRecent(limit)`
- `exports.nexa_anticheat:getStatus()`

Alle ablehnenden Pfade werden auditierbar erfasst und geloggt. Sanktionen werden nicht ausgefuehrt.

## Offene Integration

Bestehende Fachresource-Events muessen schrittweise ueber die Secure Event Registry registriert und vor Verarbeitung ueber `anticheat.validateEvent` validiert werden. Phase 12B stellt dafuer den zentralen Schutzkern bereit; fachliche Migrationen duerfen nur die bestehenden API-Contracts nutzen und keine eigene Event-Security erfinden.
