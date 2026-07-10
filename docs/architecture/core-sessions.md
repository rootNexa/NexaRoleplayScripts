# Nexa Core Player Sessions

Stand: 2026-07-10

Eine Player Session beschreibt eine aktuelle Verbindung eines Spielers zum Server. Sie ist bewusst nicht dasselbe wie Account, Charakter, Profil, Rolle, Permission oder Gameplay-State.

## Modell

Eine Session ist keine Account-Instanz und enthaelt:

- `id`: eindeutige Runtime-Session-ID.
- `source`: aktuelle FiveM-Source.
- `state`: aktueller Session-Zustand.
- `license`: primaerer Rockstar/FiveM-License-Identifier.
- `identifiers`: erlaubte ergaenzende Identifier.
- `connectedAt`: Zeitpunkt der Verbindung.
- `lastActivityAt`: letzte Aktivitaet.
- `heartbeatAt`: letzter Touch/Heartbeat.
- `dropReason`: Grund fuer Schliessung oder Ablehnung.
- `metadata`: sichere Metadaten, zum Beispiel maskierte IP und Anzeigename.

Sessions leben nur zur Laufzeit. Account-Persistenz liegt in `nexa_players`; Charakterzustand liegt in `nexa_characters` und dem Character-Core.

## Zustände

Unterstuetzte Zustaende:

- `connecting`: Source ist bekannt, Identifier werden erfasst.
- `authenticated`: Pflicht-Identifier ist vorhanden.
- `active`: Session ist gueltig und an die Source gebunden.
- `dropping`: Session wird gerade geschlossen.
- `closed`: Session wurde sauber geschlossen.
- `rejected`: Session wurde abgelehnt, zum Beispiel wegen fehlender License.

Ungueltige Zustandswechsel werden blockiert und geloggt.

## Identifier-Regeln

Primaerer Identifier:

- `license`
- falls keine `license` vorhanden ist, `license2`

Ergaenzende Identifier:

- `discord`
- `fivem`
- `steam`, falls vorhanden

IP-Adressen werden nicht als Account-Identifier verwendet und nicht als vollstaendiger dauerhafter Identifier gespeichert. Die Session-Metadaten duerfen nur eine maskierte IP enthalten, zum Beispiel `127.0.x.x`.

Nicht erlaubt:

- erfundene Hardware-IDs
- IP als alleiniger Account-Identifier
- Clientseitig behauptete Identifier ohne serverseitige Erfassung

## Datenschutz

Der Core speichert nur benoetigte Identifier. Vollstaendige IP-Adressen werden in Sessions nicht dauerhaft abgelegt. Logs laufen ueber `Nexa.Logger`, wodurch sensible Felder maskiert werden. Session-Events sollen nur public Session Snapshots enthalten.

## Reconnect und Source-Wiederverwendung

Wenn dieselbe License bereits eine aktive Session besitzt, wird die alte Session beim Reconnect kontrolliert geschlossen. Wenn dieselbe Source erneut genutzt wird, wird die vorhandene aktive Session ebenfalls geschlossen, bevor die neue Session aktiv wird.

## EventBus

Sessions emittieren interne Events:

- `nexa:internal:session:created`
- `nexa:internal:session:removed`

Diese Events transportieren Session-Snapshots, keine autoritativen Gameplay-Daten.

## Interne API

- `Sessions.Create(source, identifiers)`
- `Sessions.GetBySource(source)`
- `Sessions.GetById(sessionId)`
- `Sessions.GetByLicense(license)`
- `Sessions.SetState(sessionId, state)`
- `Sessions.Touch(sessionId)`
- `Sessions.Close(source, reason)`
- `Sessions.IsActive(source)`
- `Sessions.GetCount()`
- `Sessions.Cleanup()`

## Abgrenzung

Nicht Teil der Session:

- Charakterauswahl
- Inventar
- Geld
- Job
- Spawn
- Kleidung
- Gameplay-State

Diese Daten muessen in eigenen Domain-Systemen verwaltet werden und duerfen eine Session nur als aktuelle Verbindung referenzieren.
