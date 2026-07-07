# nexa_api

Zentrale API-Infrastruktur und Contracts.

## Zweck

- API-Contracts registrieren
- Standard-Responses bereitstellen
- Core-Bridges zu Audit, Security und Permissions anbieten
- Qbox-Bridge-Status bereitstellen
- Charakter- und Identitaets-API fuer Phase 4A bereitstellen
- Dokument- und Lizenz-API fuer Phase 4B bereitstellen
- Account-API fuer Phase 4C Banking als einzige Geld-Schreibgrenze bereitstellen
- Job- und Business-API fuer Phase 4D bereitstellen
- Dispatch-API fuer Phase 4E bereitstellen
- Garage-, Fahrzeugschluessel-, Fahrzeughaendler-, Kraftstoff- und Verwahrungs-API fuer Phase 6A bis 6E bereitstellen
- Property-API fuer Phase 7A Housing Core und Phase 7B Property Access / Keys bereitstellen
- EMS-API fuer Phase 8C als einzige Schreibgrenze fuer Patientenakten und Behandlungen bereitstellen
- Government-Gebuehren fuer Phase 8D ueber die bestehende Account-Invoice-Struktur bereitstellen

## Abhaengigkeiten

- `ox_lib`
- `oxmysql`
- `ox_inventory`
- `qbx_core`
- `nexa_config`
- `nexa_security`
- `nexa_audit`
- `nexa_permissions`
- `nexa_logs`

## Exports

- `getStatus()`
- `getContract(name)`
- `listContracts()`
- `buildResponse(success, code, message, data, meta, auditId)`
- `writeAudit(entry)`
- `audit.write(entry)`
- `checkSecurityRateLimit(source, eventName)`
- `security.checkRateLimit(source, eventName)`
- `hasPermission(source, permission)`
- `permission.has(source, permission)`
- `prepareServerNotification(source, message, notificationType)`
- `notification.send(source, message, notificationType)`
- `getQboxBridgeStatus()`
- `listCharacters(source)`
- `character.list(source)`
- `createCharacter(source, payload)`
- `character.create(source, payload)`
- `selectCharacter(source, characterId)`
- `character.select(source, characterId)`
- `deleteCharacter(source, characterId)`
- `character.delete(source, characterId)`
- `getActiveCharacter(source)`
- `character.getActive(source)`
- `getIdentity(characterId)`
- `identity.get(characterId)`
- `validateCitizenId(citizenId)`
- `character.validateCitizenId(citizenId)`
- `listDocumentTypes()`
- `document.listTypes()`
- `issueDocument(source, payload)`
- `document.issue(source, payload)`
- `revokeDocument(source, payload)`
- `document.revoke(source, payload)`
- `validateDocument(payload)`
- `document.validate(payload)`
- `listLicenseTypes()`
- `license.listTypes()`
- `issueLicense(source, payload)`
- `license.issue(source, payload)`
- `revokeLicense(source, payload)`
- `license.revoke(source, payload)`
- `validateLicense(payload)`
- `license.validate(payload)`
- `getLicenseHistory(payload)`
- `license.history(payload)`
- `createPrivateAccount(source, payload)`
- `account.createPrivate(source, payload)`
- `listAccounts(source)`
- `account.list(source)`
- `getAccountTransactions(source, payload)`
- `account.getTransactions(source, payload)`
- `transferMoney(source, payload)`
- `account.transfer(source, payload)`
- `addMoney(source, payload)`
- `account.addMoney(source, payload)`
- `addSystemMoney(source, payload)`
- `account.addSystemMoney(source, payload)`
- `createBusinessAccount(source, payload)`
- `account.createBusiness(source, payload)`
- `removeMoney(source, payload)`
- `account.removeMoney(source, payload)`
- `createMedicalInvoice(source, payload)`
- `account.createMedicalInvoice(source, payload)`
- `createGovernmentInvoice(source, payload)`
- `account.createGovernmentInvoice(source, payload)`
- `listInvoices(source, payload)`
- `account.listInvoices(source, payload)`
- `payInvoice(source, payload)`
- `account.payInvoice(source, payload)`
- `job.list()`
- `job.getCharacter(source, payload)`
- `job.assign(source, payload)`
- `job.startDuty(source, payload)`
- `job.endDuty(source, payload)`
- `job.paySalary(source, payload)`
- `business.create(source, payload)`
- `business.list(source)`
- `business.addMember(source, payload)`
- `business.removeMember(source, payload)`
- `business.listAccounts(source, payload)`
- `business.transfer(source, payload)`
- `business.listTransactions(source, payload)`
- `dispatch.createCall(source, payload)`
- `dispatch.listCalls(source, payload)`
- `dispatch.assignCall(source, payload)`
- `dispatch.updateStatus(source, payload)`
- `dispatch.setPriority(source, payload)`
- `ems.listRecords(source, payload)`
- `ems.createRecord(source, payload)`
- `ems.addTreatment(source, payload)`
- `vehicle.listGarage(source, payload)`
- `vehicle.storeGarage(source, payload)`
- `vehicle.retrieveGarage(source, payload)`
- `vehicle.reconcileGarage()`
- `vehicle.hasKey(source, payload)`
- `vehicle.grantKey(source, payload)`
- `vehicle.revokeKey(source, payload)`
- `vehicle.cleanupExpiredKeys()`
- `vehicle.toggleLock(source, payload)`
- `vehicle.purchaseDealer(source, payload)`
- `vehicle.prepareDealerSale(source, payload)`
- `vehicle.getFuel(source, payload)`
- `vehicle.purchaseFuel(source, payload)`
- `vehicle.consumeFuel(source, payload)`
- `vehicle.getImpoundStatus(source, payload)`
- `vehicle.impound(source, payload)`
- `vehicle.releaseImpound(source, payload)`
- `property.list(source, payload)`
- `property.listAccessible(source, payload)`
- `property.getStatus(source, payload)`
- `property.hasAccess(source, payload)`
- `property.grantAccess(source, payload)`
- `property.listAccess(source, payload)`
- `property.revokeAccess(source, payload)`
- `property.purchase(source, payload)`
- `property.rent(source, payload)`

## Events und Callbacks

Keine oeffentlichen Schreibevents oder Callbacks in `nexa_api`. Phase-4A-Spielerinteraktionen laufen ueber `nexa_identity`; Phase-4B-Interaktionen laufen ueber `nexa_documents` und `nexa_licenses`; Phase-4C-Interaktionen laufen ueber `nexa_banking`; Phase-4D-Interaktionen laufen ueber `nexa_jobs_core` und `nexa_business`; Phase-4E-Interaktionen laufen ueber `nexa_dispatch`; Phase-6A/6B-Interaktionen laufen ueber `nexa_garage` und `nexa_vehiclekeys`.

## Datenbanktabellen

Phase 4A nutzt ausschliesslich vorhandene Tabellen:

- `players`
- `player_identifiers`
- `characters`
- `character_status`
- `character_metadata`
- `phone_numbers`

Phase 4B nutzt zusaetzlich ausschliesslich vorhandene Tabellen:

- `documents`
- `document_types`
- `document_signatures`
- `licenses`
- `license_types`
- `license_history`

Phase 4C nutzt zusaetzlich ausschliesslich vorhandene Tabellen:

- `accounts`
- `account_members`
- `bank_transactions`
- `economy_ledger`
- `invoices`

Phase 4D nutzt zusaetzlich ausschliesslich vorhandene Tabellen:

- `jobs`
- `job_grades`
- `character_jobs`
- `duty_sessions`
- `businesses`
- `business_members`
- `business_accounts`
- `business_transactions`

Phase 4E nutzt zusaetzlich ausschliesslich vorhandene Tabellen:

- `dispatch_calls`

Phase 6A bis 6E nutzt zusaetzlich ausschliesslich vorhandene Tabellen:

- `vehicles`
- `vehicle_garage_states`
- `vehicle_keys`
- `vehicle_history`
- `vehicle_fines`

Phase 6C, 6D und 6E nutzen fuer Zahlungen zusaetzlich ausschliesslich die vorhandenen Account-Tabellen:

- `accounts`
- `account_members`
- `bank_transactions`
- `economy_ledger`

Phase 7A/7B nutzt zusaetzlich ausschliesslich vorhandene Tabellen:

- `properties`
- `property_units`
- `property_access`
- `property_transactions`
- `accounts`
- `account_members`
- `bank_transactions`
- `economy_ledger`

## Permissions

`nexa_api` ruft `nexa_permissions` nur als abhaengige Low-Level-Resource auf. `nexa_permissions` haengt nicht von `nexa_api` ab.

Phase-4B-Schreiboperationen pruefen:

- `documents.issue`
- `documents.revoke`
- `licenses.issue`
- `licenses.revoke`

Phase-8D-Government darf dieselben Document-/License-Schreiboperationen nur ueber aktive Government-Faction-Permissions nutzen:

- `government.documents.issue`
- `government.documents.revoke`
- `government.licenses.issue`
- `government.licenses.revoke`
- `government.fees.create`

Phase-8E-Weazel darf ausschliesslich `press_card`-Dokumente ueber die vorhandene Document-API ausstellen:

- `weazel.press.issue`

Phase-4C-Geldoperationen pruefen Account-Owner oder aktive `account_members`. Administrative Kontobuchungen sind fuer folgende Permissions dokumentiert:

- `account.admin.credit`
- `account.admin.debit`
- `account.audit`

Phase-4D-Schreiboperationen pruefen serverseitig:

- `jobs.assign`
- `business.create`
- `business.manage`
- `business.manageMembers`
- `business.transfer`

Gehalt wird nur bei aktiver `duty_sessions`-Session ueber `account.addSystemMoney` ausgezahlt.

Phase-4E-Schreiboperationen pruefen serverseitig:

- `dispatch.assign`
- `dispatch.status`
- `dispatch.priority`
- `dispatch.manage`

Notruf-Erstellung prueft Source, aktiven Charakter, Payload und Rate-Limit. Dispatch-Zugriff kann ueber globale Permissions, aktive `faction_members` oder passende aktive `character_jobs` erfolgen.

## Invoice-Zahlungsfluss

`account.payInvoice` bucht atomar vom zahlenden Konto ab, lockt die Rechnung in derselben Datenbanktransaktion und schreibt immer `economy_ledger`. Als Zahlungsempfaenger wird ueber die vorhandene Struktur `accounts.owner_type + owner_id` aufgeloest:

- `character` -> erstes privates Girokonto
- `business` -> Business-Konto
- `faction` -> Fraktionskonto
- `system` -> Systemkonto

Wenn fuer den Rechnungsaussteller noch kein passendes Konto existiert, bleibt `to_account_id` im Ledger `NULL` und die Zahlung wird mit `metadata.sink = true` nachvollziehbar als Ledger-Sink erfasst. Das ist ohne API-Contract-Bruch auf Businesses/Factions erweiterbar, sobald deren Konten angelegt werden.

## Fahrzeughaendler-Kauffluss

`vehicle.purchaseDealer` darf nur von `nexa_vehicledealer` genutzt werden. Der Client sendet dabei keinen Preis und kein Modell; `nexa_vehicledealer` uebergibt ausschliesslich einen serverseitig geladenen Katalogeintrag. Die Zahlung laeuft ueber den internen `account.vehiclePurchase`-Rahmen und erzeugt in derselben Datenbanktransaktion:

- Abbuchung vom Account mit `economy_ledger` und `bank_transactions`
- Fahrzeug in `vehicles`
- Garage-State `stored` in `vehicle_garage_states`
- Owner-Key in `vehicle_keys`
- Kaufereignis in `vehicle_history`

Wenn ein Teil fehlschlaegt, wird die Transaktion zurueckgerollt. Dadurch gibt es kein Geld ohne Fahrzeug und kein Fahrzeug ohne Zahlung. `vehicle.prepareDealerSale` prueft Besitz serverseitig, mutiert aber in Phase 6C noch keinen Zustand.

## Kraftstofffluss

`vehicle.purchaseFuel` darf nur von `nexa_fuel` genutzt werden. Der Client sendet keinen finalen Preis und keinen finalen Tankstand; `nexa_fuel` laedt die Tankstellen-Konfiguration serverseitig und uebergibt nur den validierten Tankwunsch an `nexa_api.vehicle`. Die Zahlung laeuft ueber den internen `account.fuelPurchase`-Rahmen und erzeugt in derselben Datenbanktransaktion:

- Abbuchung vom Account mit `economy_ledger` und `bank_transactions`
- Update von `vehicles.fuel_level`
- Tankereignis in `vehicle_history`

Wenn ein Teil fehlschlaegt, wird die Transaktion zurueckgerollt. Dadurch gibt es keinen Geldverlust ohne Fuel-Update und kein Fuel-Update ohne Zahlung. Der finale Preis entsteht aus einem innerhalb der Transaktion gelockten Tankplan, nicht aus einem Clientwert. `vehicle.consumeFuel` ist als servervalidierte Verbrauchsgrundlage vorbereitet und persistiert nur begrenzte, transaktional gelockte Deltas, damit keine Tick-Writes entstehen.

## Verwahrungsfluss

`vehicle.impound` darf nur von `nexa_impound` genutzt werden und prueft serverseitig `impound.create`, `impound.manage` oder `admin.impound`. Die Aktion setzt `vehicles.status`, `vehicle_garage_states.state`, schreibt `vehicle_history` und legt bei Gebuehr einen offenen Eintrag in `vehicle_fines` an.

`vehicle.releaseImpound` prueft Besitz oder vorbereitete Behoerden-/Adminrechte. Wenn eine Gebuehr offen ist, laeuft die Freigabe ueber den internen `account.impoundRelease`-Rahmen. Zahlung, `vehicle_fines`-Markierung, Statuswechsel und `vehicle_history` passieren in derselben Transaktion. Dadurch gibt es keine Freigabe ohne Zahlung, keine Zahlung ohne Statusaenderung und parallele Freigabe-Requests koennen den Status nicht duplizieren.

## Housing-Transaktionsfluss

`property.purchase` und `property.rent` duerfen nur von `nexa_housing` genutzt werden. Der Client sendet keinen Preis, keinen Besitzer und keinen Zielstatus; `nexa_api.property` laedt die Unit, prueft Status und Preis aus `property_units.metadata` und fuehrt die Zahlung ueber den internen `account.propertyPurchase`-Rahmen aus.

In derselben Datenbanktransaktion entstehen:

- Abbuchung vom Account mit `economy_ledger` und `bank_transactions`
- Besitzer-/Mieter-Zuweisung in `property_units`
- Zugriffseintrag in `property_access`
- Transaktionshistorie in `property_transactions`

Wenn ein Teil fehlschlaegt, wird die Transaktion zurueckgerollt. Dadurch gibt es keinen Geldverlust ohne Property-Zuweisung, keine Property-Zuweisung ohne Zahlung und parallele Kauf-/Mietrequests koennen die Unit nicht doppelt vergeben.

## Property Access / Keys

`property.grantAccess`, `property.listAccess` und `property.revokeAccess` duerfen nur von `nexa_housing` genutzt werden. Der Client entscheidet nie final ueber Besitz, Mieterstatus oder Zugriff. `nexa_api.property` laedt die Unit serverseitig, prueft den aktiven Charakter und erlaubt Verwaltung nur fuer:

- Besitzer aus `property_units.owner_character_id`
- aktive Mieter mit `property_access.access_type = 'tenant'`

Besitzer koennen `tenant`, `guest` und `temporary` vergeben. Mieter koennen nur `guest` und `temporary` vergeben. `owner` wird nicht ueber Zugriffseintraege vergeben. Temporaerer Zugriff nutzt die vorhandene Spalte `property_access.expires_at`; abgelaufene Zugriffe werden bei Zugriffspruefung, Listen und Verwaltung ignoriert.

`property.revokeAccess` loescht ausschliesslich passende Zeilen aus `property_access`. Der eigentliche Besitz in `property_units.owner_character_id` wird nie geaendert, damit ein Zugriffsentzug keine fremden Besitzrechte beschaedigt. Jede Vergabe und jeder Entzug schreibt Audit/Logging ueber die bestehenden Core-Resources.

## Housing Storage

`property.ensureStorage` und `property.openStorage` duerfen nur von `nexa_housing` genutzt werden. Der Client entscheidet nie final ueber Storage-Zugriff, sendet keinen Stash-Namen und erhaelt keine oeffnungsfaehige Stash-ID. `nexa_api.property` laedt die Unit, prueft aktive Besitzer-/Mieter-/Zugriffsrechte ueber `property_units` und `property_access`, erzeugt bei Bedarf die Zuordnung in `property_storage` sowie die Registry in `stash_registry` und registriert den Stash bei `ox_inventory`.

Die Itemlogik bleibt vollstaendig bei `ox_inventory`. Nexa speichert keine Itembestaende fuer Housing Storage, sondern nur Stash-Registry, Unit-Zuordnung und Audit-Kontext. `property.openStorage` schreibt Audit/Logging und oeffnet den Stash nach erfolgreicher Servervalidierung ueber `ox_inventory:forceOpenInventory`.

- `inventory.type = 'stash'`
- `inventory.opened = true`

Damit kann Storage spaeter ohne Breaking Change mit Furniture, Doorlock oder Interiors erweitert werden, weil Property Unit, Stash Registry und Storage Type bereits getrennt sind.

## Phase 12D Inventory Protection

Inventory Protection ist eine read-only Pruefschicht ueber `nexa_anticheat`. Die Itemlogik bleibt bei `ox_inventory`; Nexa prueft nur Zugriff, Integritaet, Item-Ledger-Muster und Stash-Registry-Kontext. Verdaechtige Vorgaenge werden auditierbar markiert und geloggt, aber nicht automatisch sanktioniert.

- `inventory.validateIntegrity`
- `inventory.validateOxAccess`
- `inventory.validateItemLedger`
- `inventory.getReconciliationReport`

## Phase 12E Vehicle Protection

Vehicle Protection ist eine read-only Pruefschicht ueber `nexa_anticheat`. Fahrzeugbesitz, Garage, Fuel, Keys, Dealer-Kaeufe und Impound bleiben serverseitig in den bestehenden Vehicle-APIs; Nexa prueft nur Integritaet, History-Muster und Status-Widersprueche. Verdaechtige Vorgaenge werden auditierbar markiert und geloggt, aber nicht automatisch sanktioniert.

- `vehicle.validateIntegrity`
- `vehicle.validateOwnership`
- `vehicle.validateGarageState`
- `vehicle.validateHistory`
- `vehicle.getReconciliationReport`

## Phase 12F Teleport Detection

Teleport Detection ist eine serverseitige Snapshot-Pruefschicht ueber `nexa_anticheat`. Der Client bestimmt nie final Position, Distanz, Geschwindigkeit oder Ausnahmegrund. Legitimes Spawn, Garage, Housing, Interior und Admin-Utility koennen serverseitig kurzlebig markiert werden; verdaechtige Bewegungen werden als suspicious movement reports auditierbar und ohne automatische Sanktion erfasst.

- `teleport.validatePositionSnapshot`
- `teleport.allow`
- `teleport.getSuspiciousReports`

## Phase 12G Noclip Detection

Noclip Detection ist eine serverseitige Pruefschicht ueber `nexa_anticheat`. Der Client bestimmt nie final Movement, Bodenkontakt oder Ausnahmegrund. Legitimes Springen, Fallen, Fahren, Beifahren, Parachute sowie Interior-, Housing- und Garage-Transitions werden ausgenommen; verdaechtige Muster werden als suspicious noclip reports auditierbar und ohne automatische Sanktion erfasst.

- `noclip.validateMovement`
- `noclip.allowException`
- `noclip.getSuspiciousReports`

## Phase 12H Godmode Detection

Godmode Detection ist eine serverseitige Pruefschicht ueber `nexa_anticheat`. Der Client bestimmt nie final Health, Armor, Invulnerability oder Damage-Ergebnis. Legitimes Heilen, Revive, EMS-Behandlung, Spawn-Protection und Admin-Aktionen koennen kurzlebig serverseitig markiert werden; verdaechtige Muster werden als suspicious godmode reports auditierbar und ohne automatische Sanktion erfasst.

- `godmode.validateState`
- `godmode.allowException`
- `godmode.recordDamageEvent`
- `godmode.getSuspiciousReports`

## Phase 12I Executor / Injection Detection

Executor / Injection Detection ist eine serverseitige Verdachtslogik ueber `nexa_anticheat`. Sie bewertet verdaechtige Event-Patterns, Resource-Patterns, ungewoehnliche Payload-Strukturen und konfigurierbare Exploit-Signaturen. Client-Tamper-Indikatoren sind untrusted Signals und niemals allein beweisend; Ergebnisse werden als suspicious executor reports auditierbar und ohne automatische Sanktion erfasst.

- `executor.validateSignal`
- `executor.getSuspiciousReports`

## Phase 12J Screenshot / Evidence Capture

Screenshot/Evidence Capture ist eine serverseitige Request-Grundstruktur ueber `nexa_anticheat`. Manuelle Admin-Anforderungen brauchen Permission, werden rate-limited, auditierbar geloggt und enthalten Evidence-Metadaten mit Datenschutz-/Transparenz-Hinweisen. Anticheat-Anforderungen sind nur als vorbereitete Schnittstelle vorhanden. In Phase 12J werden keine automatischen Massen-Screenshots, keine heimlichen oder dauerhaften Clientpruefungen, keine externe Upload-Anbindung und keine automatischen Sanktionen ausgefuehrt.

- `evidence.requestCapture`
- `evidence.prepareAnticheatCapture`
- `evidence.getCaptureRequests`

## Phase 12K Ban System

Ban System ist eine serverseitige Grundstruktur ueber `nexa_anticheat`. Bans koennen nur manuell mit Admin-Permission erstellt werden, unterstuetzen temporaere und permanente Dauer, speichern Ban-Gruende in der vorhandenen `bans`-Tabelle, verknuepfen erlaubte FiveM-Identifier ueber `player_identifiers` und pruefen aktive Bans beim Join. Appeal-/Review-Status ist als vorbereitete Struktur in Responses enthalten. Anticheat-Bans, Hardware-ID-/invasive Tracking-Systeme, externe Webpanel-/Discord-Anbindungen und Gameplayaenderungen sind nicht enthalten.

- `ban.createManual`
- `ban.checkSource`
- `ban.getHistory`

## Phase 7D - Furniture API

`nexa_api.property` stellt fuer `nexa_furniture` folgende serverseitige Contracts bereit:

- `property.listFurniture`
- `property.placeFurniture`
- `property.saveFurniture`
- `property.removeFurniture`

Alle schreibenden Aktionen pruefen aktiven Property-Zugriff und erlauben Persistenz nur fuer Besitzer oder Mieter. Position und Rotation werden im Server validiert; Platzierungsgrenzen muessen ueber `property_units.metadata.furniture.bounds` serverseitig konfiguriert sein. Der Client darf Zugriff, Besitz oder Transform nie final entscheiden.

## Config-Werte

- `version`
- `defaultStatus`
- `requireContracts`

## Testhinweise

Phase-4C-Contracts werden ueber `tools/windows/Test-Phase4CBanking.ps1` geprueft. Phase-4D-Grenzen werden ueber `tools/windows/Test-Phase4DJobsBusiness.ps1` geprueft. Phase-4E-Grenzen werden ueber `tools/windows/Test-Phase4EDispatch.ps1` geprueft. Phase-6C-Grenzen werden ueber `tools/windows/Test-Phase6CVehicleDealer.ps1`, Phase-6D-Grenzen ueber `tools/windows/Test-Phase6DFuel.ps1`, Phase-6E-Grenzen ueber `tools/windows/Test-Phase6EImpound.ps1`, Phase-7A-Grenzen ueber `tools/windows/Test-Phase7AHousing.ps1`, Phase-7B-Grenzen ueber `tools/windows/Test-Phase7BPropertyAccess.ps1` und Phase-7C-Grenzen ueber `tools/windows/Test-Phase7CHousingStorage.ps1` geprueft.
