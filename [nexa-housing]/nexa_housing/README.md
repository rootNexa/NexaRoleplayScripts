# nexa_housing

Housing Core fuer Phase 7A, Property Access / Keys fuer Phase 7B und Housing Storage fuer Phase 7C.

## Umgesetzt

- Immobilienliste ueber `nexa_api.property.list`
- zugreifbare Property Units ueber `property.listAccessible`
- Status- und Besitzerpruefung ueber `property.getStatus`
- Zugriffsbasis ueber `property.hasAccess` und `property.grantAccess`
- Zugriffsliste ueber `property.listAccess`
- Zugriffsentzug ueber `property.revokeAccess`
- temporaerer Zugriff ueber `property_access.expires_at`
- Kauf- und Miet-Grundstruktur ueber `property.purchase` und `property.rent`
- Zahlung nur ueber den internen `nexa_api.account`-Transaktionsrahmen
- atomare Zuweisung von `property_units`, `property_access`, `property_transactions`, `economy_ledger` und `bank_transactions`
- serverseitige Payload-, Status-, Besitzer-, Account- und Preisvalidierung
- Rate-Limits ueber `nexa_security`
- Audit/Logging ueber `nexa_audit` und `nexa_logs`
- minimale ox_lib-Callbacks und Client-Notifications
- Property-Storage-Vorbereitung ueber `property.ensureStorage`
- Storage-Oeffnung ueber `property.openStorage`
- Stash-Registrierung ueber `stash_registry`, `property_storage` und `ox_inventory:RegisterStash`
- serverseitiges Oeffnen ueber `ox_inventory:forceOpenInventory`
- ox_inventory-kompatible Oeffnungsgrundlage ohne eigene Itemlogik

## Grenzen

- Der Client sendet nie Preis, Status oder Besitzer.
- Der Client entscheidet nie final ueber Property-Zugriff.
- Besitzer koennen Mieter, Gaeste und temporaeren Zugriff verwalten.
- Mieter koennen Gaeste und temporaeren Zugriff verwalten.
- Zugriffsentzug loescht nur `property_access` und veraendert nie `property_units.owner_character_id`.
- Zugriffsentzug loescht ausschliesslich passende Zeilen aus `property_access`.
- Kauf/Miete lockt die Unit in der Datenbanktransaktion und aktualisiert nur `available` Units.
- Zahlung und Property-Zuweisung werden gemeinsam committed oder gemeinsam zurueckgerollt.
- Parallele Requests werden zusaetzlich pro Source, Aktion und Unit kurz gesperrt.
- Der Client sendet keinen Stash-Namen und entscheidet nie final ueber Storage-Zugriff.
- Der Client erhaelt keine oeffnungsfaehige Stash-ID.
- Nur aktive Besitzer, Mieter oder berechtigte Property-Zugriffe duerfen Storage oeffnen.
- Nexa speichert keine Itembestaende; Itemlogik bleibt bei `ox_inventory`.
- Storage bleibt ueber `property_storage.storage_type` spaeter fuer Furniture, Doorlock oder Interiors erweiterbar.

## Ausgeschlossen

- Furniture
- komplexes Interior-System
- Doorlock-Vollintegration
- Polizei-/EMS-Systeme
- illegale Systeme
- grosse UI-Systeme
