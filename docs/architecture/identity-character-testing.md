# Identity and Character Testing

Stand: 2026-07-10

## Statische Tests

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-identity-character.ps1
```

Der Validator prueft:

- keine verbotenen Framework-Abhaengigkeiten
- keine direkte `MySQL.*`-Nutzung in `nexa_identity` oder `nexa_characters`
- keine Hardware-ID-Logik
- Identity-Exports
- Character-Exports
- Migrationen
- Startreihenfolge in `server/foundation.dev.cfg`
- Kern-Dokumentation

## Identity-Runtime-Tests

Nur in einer echten FXServer-Instanz:

- neuer Account
- bestehender Account
- fehlende License
- zusaetzliche Identifier
- Identifier-Normalisierung
- Account gesperrt
- Account deaktiviert
- Account `pending_review`
- Multi-Account starkes Signal
- Multi-Account schwaches Signal
- gleiche IP ohne automatische Sperre
- Cache und Invalidierung
- Disconnect Cleanup

## Character-Runtime-Tests

Nur in einer echten FXServer-Instanz:

- leere Charakterliste
- Charakter erstellen
- Pflichtfeld fehlt
- ungueltiger Name
- ungueltiges Geburtsdatum
- ungueltige Groesse
- ungueltiges Gewicht
- Slotlimit
- belegter Slot
- fremder Charakter
- Charakter auswaehlen
- doppelte Auswahl
- parallele Auswahl
- bereits aktiver Charakter
- Disconnect Release
- Soft-Delete
- geloeschten Charakter auswaehlen
- administrative Aenderung ohne Permission
- administrative Aenderung mit Permission
- alte Core-Export-Kompatibilitaet

## Nicht lokal ausgefuehrt

Wenn `FXServer.exe` nicht verfuegbar ist, duerfen Runtime-Tests nicht als bestanden gemeldet werden. Sie bleiben offen und werden in der Abschlussmeldung aufgefuehrt.
