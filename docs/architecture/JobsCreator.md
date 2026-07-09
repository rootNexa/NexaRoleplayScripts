# JobsCreator Architecture

## 1. Vision

`nexa_jobscreator` ist die zentrale Grundlage fuer ingame erstellbare Jobs, Gangs, Fraktionen und Organisationen in Nexa Roleplay. Das Ziel ist ein eigenes, generisches System, das Organisationen nicht mehr ueber feste Ressourcen modelliert, sondern ueber Daten, Module, Ränge und Berechtigungen.

Feste Hauptressourcen wie `nexa_lspd`, `nexa_ems`, `nexa_government` und `nexa_weazel` sollen langfristig ersetzt werden, weil sie dieselben Grundprobleme mehrfach loesen:

- Mitgliederverwaltung
- Ränge und Dienststatus
- Fahrzeuge, Garagen und Ausruestung
- Dispatch- und MDT-Zugriff
- Rechnungen, Dokumente und Akten
- Whitelists und Berechtigungen
- storage-, evidence-, armory- oder medical-spezifische Erweiterungen

Diese Logik gehoert nicht in viele harte Sonderressourcen. Sie gehoert in eine generische Organisationsschicht. Eine Polizeiorganisation, eine EMS-Organisation, eine Gang, ein Unternehmen oder eine Medienorganisation unterscheiden sich nicht durch eigene Frameworks, sondern durch:

- `organization_type`
- `mdt_type`
- aktivierte Module
- Grade
- Permissions
- Konfiguration
- optionale visuelle Identitaet

JobsCreator ist damit nicht nur ein Admin-Werkzeug. Es ist die fachliche Quelle fuer alle spielbaren Organisationen. Andere Ressourcen fragen JobsCreator, ob eine Organisation ein Modul besitzt, welche Berechtigungen ein Mitglied hat, welche Ränge existieren und wie die Organisation im MDT, Dispatch, Garagen- oder Dokumentensystem erscheinen soll.

Das System bleibt serverautoritativ. Die UI darf nie allein entscheiden, ob eine Organisation, ein Rang, ein Modul oder eine Berechtigung gueltig ist. Alle kritischen Entscheidungen muessen durch serverseitige APIs, Callbacks und spaeter durch Audit-/Permission-Systeme abgesichert werden.

## 2. Benutzerfluss

Der Kernfluss fuer Serveradministratoren ist:

1. Serveradmin oeffnet JobsCreator.
2. JobsCreator zeigt eine Liste bestehender Organisationen.
3. Serveradmin waehlt `Neue Organisation`.
4. Serveradmin legt Name und Label fest.
5. Serveradmin waehlt einen Organisationstyp.
6. Serveradmin waehlt einen MDT-Typ.
7. Serveradmin waehlt Module.
8. Serveradmin konfiguriert die Module.
9. Serveradmin erstellt Ränge.
10. Serveradmin vergibt Berechtigungen pro Rang.
11. Serveradmin setzt optionale Organisationseigenschaften wie Farben, Logo, Standardgarage, Dispatch-Optionen, Storage-Optionen, Whitelist.
12. Serveradmin speichert.
13. JobsCreator validiert alles serverseitig.
14. Organisation ist sofort spielbar.

Der Zielzustand ist:

```text
Serveradmin
  ↓
JobsCreator
  ↓
Organisationen
  ↓
Neue Organisation
  ↓
Typ wählen
  ↓
Module wählen
  ↓
Ränge
  ↓
Speichern
  ↓
Organisation ist sofort spielbar
```

Ein Minimalfall soll moeglich sein:

- Name: `lspd`
- Label: `Los Santos Police Department`
- Type: `police`
- MDT Type: `police`
- Module: `mdt`, `dispatch`, `garage`, `armory`, `evidence`, `impound`, `radio`
- Ränge: `chief`, `captain`, `officer`, `cadet`

Nach dem Speichern kann ein berechtigter Admin Mitglieder hinzufuegen, Ränge zuweisen und Spieler koennen Dienststatus, MDT, Dispatch und Garagen nutzen, sofern die jeweiligen Module und Permissions vorhanden sind.

## 3. Organisation

Eine Organisation ist die zentrale Einheit des Systems. Sie repraesentiert einen Job, eine Gang, eine Fraktion, ein Unternehmen, eine Medienorganisation, eine Regierungsstelle oder einen freien Custom-Typ.

Pflichtfelder:

- `id`: eindeutige technische ID.
- `name`: technischer Slug, zum Beispiel `lspd`, `sams`, `gruppe6`, `weazel_news`.
- `label`: sichtbarer Anzeigename.
- `organization_type`: fachlicher Typ, zum Beispiel `police`.
- `mdt_type`: MDT-Profil, zum Beispiel `police`, `ems`, `business`, `none`.
- `enabled`: legt fest, ob die Organisation aktiv nutzbar ist.

Geplante erweiterte Eigenschaften:

- `modules`: Liste aktivierter Organisationsmodule.
- `colors`: visuelle Farbvorgaben.
- `logo`: Logo-Asset oder Asset-Key.
- `defaultGarage`: Standardgarage fuer Organisationsfahrzeuge.
- `dispatch`: Dispatch-Konfiguration.
- `storage`: Storage-Konfiguration.
- `whitelist`: legt fest, ob Mitgliedschaft nur durch berechtigte Personen vergeben werden kann.
- `metadata`: generische Erweiterungsdaten fuer spaetere Features.

### Name

Der Name ist ein stabiler technischer Slug. Er sollte kleingeschrieben sein und nur Buchstaben, Zahlen, `_` oder `-` enthalten. Der Name darf nach Erstellung nur mit besonderer Migration geaendert werden, weil andere Systeme ihn referenzieren koennen.

Beispiele:

- `lspd`
- `sams`
- `doj`
- `lost_mc`
- `weazel_news`
- `bean_machine`

### Label

Das Label ist der sichtbare Name fuer UI, MDT, Dispatch, Logs und Benachrichtigungen.

Beispiele:

- `Los Santos Police Department`
- `San Andreas Medical Services`
- `Department of Justice`
- `The Lost MC`
- `Weazel News`

### Typ

Der Organisationstyp beschreibt die fachliche Kategorie. Er darf keine festen Ressourcen erzwingen. Ein Typ darf Standardvorschlaege fuer Module, Ränge und Permissions liefern, aber nie harte Sonderlogik erzwingen.

### MDT Type

Der MDT-Typ beschreibt, welche MDT-Oberflaeche standardmaessig erzeugt wird. Er kann vom Organisationstyp abweichen. Eine Regierungsorganisation koennte zum Beispiel `organization_type = government` und `mdt_type = police` besitzen, wenn sie Vollzugsbefugnisse hat.

`mdt_type = none` bedeutet: Diese Organisation bekommt kein MDT-Profil.

### Module

Module legen fest, welche Funktionen eine Organisation besitzt. Ein Modul ist eine aktivierte Faehigkeit, nicht zwingend eine eigene Resource.

Beispiele:

- `garage`: Organisationsgarage verfuegbar.
- `billing`: Organisation kann Rechnungen stellen.
- `dispatch`: Organisation nimmt am Dispatch teil.
- `armory`: Organisation hat Ausruestungszugriff.

### Farben

Farben dienen nur der Darstellung. Sie duerfen keine Berechtigungen oder Fachlogik transportieren.

Empfohlene Felder:

- `primary`
- `secondary`
- `accent`
- `text`

### Logo

Das Logo ist ein Asset-Key oder eine URL/Dateireferenz innerhalb eines kontrollierten Asset-Systems. Logos werden im MDT, JobsCreator, Dispatch und in Dokumenten angezeigt.

### Standardgarage

Die Standardgarage ist der erste Spawn-/Parkbereich der Organisation. Sie wird nur wirksam, wenn das Modul `garage` aktiv ist.

### Dispatch

Dispatch-Konfiguration beschreibt, ob die Organisation:

- Dispatch-Meldungen empfaengt.
- Dispatch-Meldungen erstellen darf.
- eigene Dispatch-Kategorien besitzt.
- eigene Prioritaeten besitzt.
- mit anderen Organisationen Dispatch-Kanaele teilt.

### Storage

Storage-Konfiguration beschreibt:

- ob ein Organisationslager existiert.
- welche Ränge oder Permissions Zugriff haben.
- ob private, rangbezogene oder modulbezogene Lager existieren.

### Aktiviert

`enabled = false` deaktiviert die Organisation fuer Gameplay-Zugriffe. Daten bleiben erhalten.

Deaktivierte Organisationen:

- erscheinen nicht in normaler Spielerauswahl.
- duerfen keine neuen Duty-Sessions starten.
- sollen keine Dispatch-/MDT-Module fuer Spieler bereitstellen.
- bleiben fuer Admins sichtbar.

### Whitelist

Whitelist bedeutet: Mitglieder koennen nicht durch Self-Service beitreten. Mitgliedschaft muss durch berechtigte Personen vergeben werden.

Whitelist ist bei `police`, `ems`, `government` standardmaessig empfohlen.

## 4. Organisationstypen

Unterstuetzte Typen:

- `police`
- `ems`
- `government`
- `gang`
- `business`
- `media`
- `custom`

### police

Fuer Polizeibehoerden, Sheriff Departments, State Police, Ermittlungsbehoerden und aehnliche Vollzugsorganisationen.

Empfohlene Module:

- `mdt`
- `dispatch`
- `garage`
- `armory`
- `evidence`
- `radio`
- `impound`
- `documents`

### ems

Fuer Rettungsdienst, Feuerwehr, Kliniken und medizinische Organisationen.

Empfohlene Module:

- `mdt`
- `dispatch`
- `garage`
- `medical`
- `billing`
- `radio`
- `documents`

### government

Fuer Regierung, Justiz, Stadtverwaltung, Department of Justice und Lizenzaussteller.

Empfohlene Module:

- `mdt`
- `documents`
- `billing`
- `licenses`
- `recruitment`

### gang

Fuer Gangs, MCs, Crime-Familien und informelle Gruppierungen.

Empfohlene Module:

- `storage`
- `garage`
- `radio`
- `billing`
- `custom`

### business

Fuer Unternehmen, Werkstaetten, Clubs, Restaurants, Shops und private Arbeitgeber.

Empfohlene Module:

- `billing`
- `garage`
- `storage`
- `documents`
- `recruitment`

### media

Fuer Medienorganisationen, Presse, Reporter und Event-Teams.

Empfohlene Module:

- `documents`
- `garage`
- `radio`
- `billing`
- `recruitment`

### custom

Freier Organisationstyp fuer Server-spezifische Konzepte. `custom` darf keine Sonderlogik voraussetzen. Alle Funktionen entstehen ueber Module und Permissions.

## 5. Module

Module sind optionale Funktionsbereiche einer Organisation. Sie werden im JobsCreator zugewiesen und koennen spaeter konfiguriert werden.

Module duerfen keine festen Organisationstypen voraussetzen. Ein Police-Department kann `medical` besitzen, wenn ein Server das will. Ein Business kann `dispatch` besitzen, wenn es eine Sicherheitsfirma ist.

### MDT

Erlaubt Zugriff auf das generische MDT. Das MDT rendert seine Module anhand von Organisation, MDT-Typ, aktivierten Modulen und Permissions.

Typische Permissions:

- `mdt.use`
- `mdt.manage`

### Dispatch

Erlaubt Senden, Empfangen und Bearbeiten von Dispatch-Meldungen.

Typische Permissions:

- `dispatch.view`
- `dispatch.manage`

### Garage

Erlaubt Organisationsfahrzeuge, Spawns, Einparken, Ausparken und Fahrzeugverwaltung.

Typische Permissions:

- `garage.use`
- `garage.manage`
- `vehicle.spawn`
- `vehicle.manage`

### Storage

Erlaubt Organisationslager und Inventarbereiche.

Typische Permissions:

- `storage.use`
- `storage.manage`

### Billing

Erlaubt Rechnungen, Gebuehren, Strafzettel, Kundenrechnungen oder interne Zahlungsforderungen.

Typische Permissions:

- `billing.view`
- `billing.manage`

### Evidence

Erlaubt Beweisverwaltung, Asservatenkammer, Case-Verknuepfung und Evidence-Status.

Typische Permissions:

- `evidence.view`
- `evidence.manage`

### Armory

Erlaubt Ausruestungsausgabe, Waffenlager, Loadouts und Rueckgabe.

Typische Permissions:

- `armory.use`
- `armory.manage`

### Medical

Erlaubt Patientenakten, Behandlungen, Diagnosen, medizinische Reports und Versorgungslogik.

Typische Permissions:

- `medical.use`
- `medical.manage`

### Documents

Erlaubt Dokumente ausstellen, ansehen, widerrufen und verwalten.

Typische Permissions:

- `documents.view`
- `documents.issue`
- `documents.manage`

### Radio

Erlaubt Organisationsfunk, Funkkanaele und Zugriffsregeln.

Typische Permissions:

- `radio.use`
- `radio.manage`

### Impound

Erlaubt Abschleppen, Sicherstellen, Freigeben und Verwalten von Fahrzeugen.

Typische Permissions:

- `impound.use`
- `impound.manage`

### Licenses

Erlaubt Lizenzen ausstellen, pruefen, entziehen und verwalten.

Typische Permissions:

- `licenses.view`
- `licenses.issue`
- `licenses.manage`

### Vehicle Shop

Erlaubt Fahrzeugverkauf, Flottenkataloge, Organisationseinkauf und Fahrzeuguebergaben.

Typische Permissions:

- `vehicleshop.use`
- `vehicleshop.manage`

### Recruitment

Erlaubt Bewerbungen, Einladungen, Probezeiten und Member-Onboarding.

Typische Permissions:

- `recruitment.view`
- `recruitment.manage`

### Custom

Platzhalter fuer Server-spezifische Module. Custom-Module muessen registriert, benannt und serverseitig validiert werden. Sie duerfen nicht heimlich feste Legacy-Ressourcen nachbauen.

Typische Permissions:

- `custom.use`
- `custom.manage`

## 6. Grade-System

Grades sind generische Ränge innerhalb einer Organisation. Sie bestehen aus:

- `id`
- `organization_id`
- `name`
- `label`
- `level`
- `permissions`

`level` beschreibt die Hierarchie. Hoehere Werte bedeuten mehr Rangautoritaet. Gameplay darf sich nicht ausschliesslich auf `level` verlassen. Kritische Funktionen muessen Permissions pruefen.

Beispiel fuer eine Polizeiorganisation:

| Name | Label | Level |
| --- | --- | --- |
| owner | Owner | 100 |
| chief | Chief | 90 |
| captain | Captain | 70 |
| lieutenant | Lieutenant | 60 |
| sergeant | Sergeant | 50 |
| officer | Officer | 30 |
| cadet | Cadet | 10 |

Dieses Beispiel ist nicht verpflichtend. Eine Gang koennte `boss`, `underboss`, `soldier`, `prospect` verwenden. Ein Business koennte `owner`, `manager`, `employee`, `trainee` verwenden.

Grade-Regeln:

- Jeder Rang gehoert zu genau einer Organisation.
- Rangnamen sind technische Slugs.
- Ranglabels sind frei sichtbar.
- Permissions werden am Rang gespeichert.
- Spaeter koennen individuelle Member-Overrides ergaenzt werden, aber der erste Standard ist rangbasiert.
- Ein Rang darf geloescht werden, wenn keine kritischen Verweise blockieren oder wenn Mitglieder auf `nil`/Fallback gesetzt werden.

## 7. Permission-System

JobsCreator verwendet keine festen Rollen fuer Funktionen. Rollen/Grades sind nur Container fuer Berechtigungen.

Eine Permission ist ein String mit Domain und Aktion:

```text
domain.action
```

Beispiele:

- `members.view`
- `members.manage`
- `garage.use`
- `garage.manage`
- `dispatch.manage`
- `dispatch.view`
- `storage.use`
- `storage.manage`
- `billing.manage`
- `billing.view`
- `mdt.use`
- `mdt.manage`
- `organization.manage`
- `module.manage`
- `grade.manage`
- `vehicle.spawn`
- `vehicle.manage`
- `documents.issue`
- `documents.view`
- `documents.manage`
- `medical.use`
- `medical.manage`
- `evidence.view`
- `evidence.manage`
- `armory.use`
- `armory.manage`
- `radio.use`
- `radio.manage`
- `impound.use`
- `impound.manage`
- `licenses.view`
- `licenses.issue`
- `licenses.manage`
- `recruitment.view`
- `recruitment.manage`

Permission-Regeln:

- Server prueft Permissions fuer jede kritische Aktion.
- UI darf nur ausblenden, aber nie autorisieren.
- Module duerfen eigene Permissions definieren.
- Permissions sollten stabil und dokumentiert sein.
- Wildcards koennen spaeter eingefuehrt werden, sind aber nicht Grundlage der ersten Architektur.
- `organization.manage` darf nicht automatisch alle Modulrechte bedeuten.
- `module.manage` erlaubt Modulzuweisung und Modulkonfiguration, nicht automatisch die Nutzung aller Module.
- `grade.manage` erlaubt Rangverwaltung, nicht automatisch Mitgliederverwaltung.

Empfohlene Berechtigungsgruppen:

- Organisation: `organization.view`, `organization.manage`
- Mitglieder: `members.view`, `members.manage`
- Ränge: `grade.view`, `grade.manage`
- Module: `module.view`, `module.manage`
- Duty: `duty.use`, `duty.manage`
- MDT: `mdt.use`, `mdt.manage`
- Dispatch: `dispatch.view`, `dispatch.manage`
- Garage: `garage.use`, `garage.manage`
- Fahrzeuge: `vehicle.spawn`, `vehicle.manage`
- Storage: `storage.use`, `storage.manage`
- Billing: `billing.view`, `billing.manage`
- Documents: `documents.view`, `documents.issue`, `documents.manage`
- Medical: `medical.use`, `medical.manage`
- Evidence: `evidence.view`, `evidence.manage`
- Armory: `armory.use`, `armory.manage`
- Radio: `radio.use`, `radio.manage`
- Impound: `impound.use`, `impound.manage`

## 8. MDT

`nexa_mdt` soll generisch sein. Es darf keine feste LSPD-, EMS-, Government- oder Weazel-Architektur enthalten.

Das MDT erzeugt seine Oberflaeche aus:

- `organization_type`
- `mdt_type`
- aktivierten Modulen
- Permissions des aktiven Members
- Modulkonfiguration
- optionalen Server-Featureflags

Beispiel:

Eine Organisation hat:

- `organization_type = police`
- `mdt_type = police`
- Module: `mdt`, `dispatch`, `evidence`, `impound`, `documents`
- Member-Permissions: `mdt.use`, `dispatch.view`, `evidence.manage`

Das MDT zeigt dann:

- Basisnavigation fuer `police`
- Dispatch-Ansicht lesend
- Evidence-Ansicht verwaltend
- keine Impound-Aktionen, falls `impound.use` fehlt
- keine Documents-Ausstellung, falls `documents.issue` fehlt

MDT-Regeln:

- Ohne Modul `mdt` gibt es keinen MDT-Zugriff.
- Ohne `mdt.use` gibt es keinen MDT-Zugriff.
- `mdt_type` bestimmt Standardmodule und Layout-Vorschlaege.
- Aktivierte Module bestimmen tatsaechlich verfuegbare Bereiche.
- Permissions bestimmen Sichtbarkeit und Aktionen.
- Keine UI-Komponente darf harte Organisationsnamen wie `lspd` pruefen.
- Falls Sonderverhalten noetig ist, muss es ueber Modulkonfiguration oder Permission modelliert werden.

MDT-Typen koennen unterschiedliche Modulgruppen vorschlagen:

- `police`: persons, vehicles, warrants, reports, dispatch, evidence, impound
- `ems`: patients, treatments, reports, dispatch, billing
- `government`: documents, licenses, fees, cases
- `gang`: members, territories, reputation, storage
- `business`: employees, invoices, documents, garage
- `media`: reports, press, documents, announcements
- `none`: kein MDT

Diese Listen sind Default-Vorschlaege, keine harten Abhaengigkeiten.

## 9. JobsCreator UI

Die JobsCreator UI ist ein Admin-Werkzeug. Sie soll nicht in dieser Phase implementiert werden, aber die Architektur legt ihre Struktur fest.

### Hauptnavigation

Seiten:

- Dashboard
- Organisationen
- Module
- Templates
- Audit
- Einstellungen

### Dashboard

Zweck:

- Systemstatus anzeigen.
- Anzahl Organisationen anzeigen.
- Deaktivierte Organisationen anzeigen.
- Ungueltige Konfigurationen anzeigen.
- Letzte Aenderungen anzeigen.

Elemente:

- Statuszeile fuer JobsCreator-Backend.
- Kacheln fuer Organisationstypen.
- Warnungen fuer fehlende Ränge, fehlende Owner, Module ohne Config.
- Liste letzter Admin-Aktionen.

### Organisationen-Liste

Zweck:

- Alle Organisationen suchen, filtern und verwalten.

Filter:

- Typ
- MDT Type
- Aktiviert
- Modul
- Whitelist

Tabellen-Spalten:

- Label
- Name
- Typ
- MDT Type
- Module
- Mitglieder
- Status
- Aktionen

Aktionen:

- Oeffnen
- Duplizieren
- Deaktivieren/Aktivieren
- Loeschen nur mit Schutzdialog

### Organisation erstellen

Wizard-Schritte:

1. Grunddaten
2. Typ und MDT
3. Module
4. Ränge
5. Permissions
6. Darstellung und Optionen
7. Zusammenfassung
8. Speichern

#### Schritt Grunddaten

Felder:

- Name
- Label
- Beschreibung
- Whitelist
- Aktiviert

Validierung:

- Name ist Pflicht.
- Name ist Slug.
- Label ist Pflicht.
- Name ist eindeutig.

#### Schritt Typ und MDT

Felder:

- Organisationstyp
- MDT Type
- optionales Template

Verhalten:

- Typauswahl schlaegt Module und Ränge vor.
- MDT Type schlaegt MDT-Module vor.
- Vorschlaege koennen angepasst werden.

#### Schritt Module

Darstellung:

- Modulraster mit Toggle pro Modul.
- Moduldetails rechts oder in Dialog.
- Warnhinweise bei Abhaengigkeiten.

Modulkonfiguration:

- `garage`: Standardgarage, erlaubte Fahrzeuge
- `dispatch`: Channels, Prioritaeten, Kategorien
- `storage`: Lagergroesse, Zugriff
- `billing`: Rechnungstypen, Limits
- `armory`: Loadouts, erlaubte Items
- `documents`: Dokumenttypen

#### Schritt Ränge

Funktionen:

- Rang hinzufuegen.
- Rang entfernen.
- Rang sortieren.
- Level setzen.
- Label bearbeiten.
- Slug bearbeiten.
- Rang aus Template uebernehmen.

Default-Vorlagen:

- Police-Vorlage
- EMS-Vorlage
- Government-Vorlage
- Business-Vorlage
- Gang-Vorlage
- Media-Vorlage
- Leere Vorlage

#### Schritt Permissions

Darstellung:

- Matrix: Ränge als Spalten, Permissions als Zeilen.
- Filter nach Modul.
- Schnellaktionen: alle lesen, alle verwalten, Rang kopieren.

Regeln:

- Permissions werden pro Rang gespeichert.
- UI zeigt nur Permissions, die durch aktivierte Module relevant sind.
- Basispermissions wie `organization.manage`, `members.manage`, `grade.manage` sind immer verfuegbar.

#### Schritt Darstellung und Optionen

Felder:

- Primaerfarbe
- Sekundaerfarbe
- Akzentfarbe
- Logo
- Standardgarage
- Dispatch-Anzeige
- Storage-Name
- Dokumentkopf

#### Schritt Zusammenfassung

Zeigt:

- Name und Label
- Typ und MDT Type
- Module
- Ränge
- kritische Permissions
- Warnungen

Speichern:

- Sendet eine zusammenhaengende Transaktion an den Server.
- Server validiert alles erneut.
- UI zeigt Erfolg oder Fehler.

### Organisation Detailseite

Tabs:

- Uebersicht
- Mitglieder
- Ränge
- Module
- Permissions
- Fahrzeuge
- Dokumente
- Audit
- Einstellungen

#### Uebersicht

Zeigt:

- Basisdaten
- Status
- aktive Module
- Mitgliederanzahl
- Duty-Mitglieder
- offene Warnungen

#### Mitglieder

Funktionen:

- Mitglied suchen.
- Mitglied hinzufuegen.
- Rang zuweisen.
- Callsign setzen.
- Duty-Status adminseitig sehen.
- Mitglied entfernen.

Dialoge:

- Mitglied hinzufuegen
- Rang aendern
- Callsign bearbeiten
- Entfernen bestaetigen

#### Ränge

Funktionen:

- Ränge verwalten.
- Level bearbeiten.
- Permissions oeffnen.
- Rang duplizieren.
- Rang loeschen.

#### Module

Funktionen:

- Module aktivieren.
- Module entfernen.
- Modulkonfiguration bearbeiten.
- Modulstatus pruefen.

Kontextmenues:

- Modul konfigurieren
- Modul deaktivieren
- Modul entfernen
- Permissions anzeigen

#### Permissions

Funktionen:

- Permission-Matrix bearbeiten.
- Permission nach Modul filtern.
- Rangrechte vergleichen.
- Effektive Rechte eines Mitglieds anzeigen.

#### Fahrzeuge

Nur sichtbar, wenn `garage` oder `vehicle shop` aktiv ist.

Funktionen:

- Fahrzeugliste.
- erlaubte Modelle.
- Rangbeschraenkungen.
- Spawnpunkte.

#### Dokumente

Nur sichtbar, wenn `documents` oder `licenses` aktiv ist.

Funktionen:

- Dokumenttypen.
- Lizenztypen.
- Ausstellungsrechte.
- Templates.

#### Audit

Zeigt:

- Organisationsaenderungen.
- Rang-/Permission-Aenderungen.
- Modul-Aenderungen.
- Mitglieder-Aenderungen.

#### Einstellungen

Funktionen:

- Basisdaten bearbeiten.
- Aktivieren/deaktivieren.
- Whitelist toggeln.
- Logo/Farben bearbeiten.
- Organisation archivieren.

### Dialoge

Pflichtdialoge:

- Organisation erstellen
- Organisation deaktivieren
- Organisation archivieren
- Modul konfigurieren
- Rang erstellen
- Rang bearbeiten
- Permission-Vorlage anwenden
- Mitglied hinzufuegen
- Mitglied entfernen
- Callsign bearbeiten

### Kontextmenues

Kontextmenues sollen fuer schnelle Aktionen genutzt werden:

- Organisation: oeffnen, duplizieren, deaktivieren, audit anzeigen
- Modul: konfigurieren, entfernen, permissions anzeigen
- Rang: bearbeiten, duplizieren, loeschen
- Mitglied: Rang aendern, Callsign bearbeiten, entfernen

### Workflows

#### Neue Polizeiorganisation

1. Organisation erstellen.
2. Typ `police` waehlen.
3. MDT Type `police` waehlen.
4. Template `Police Department` anwenden.
5. Module pruefen.
6. Ränge anpassen.
7. Permissions pruefen.
8. Speichern.
9. Chief-Mitglied hinzufuegen.

#### Neues Unternehmen

1. Organisation erstellen.
2. Typ `business` waehlen.
3. MDT Type `business` oder `none` waehlen.
4. Module `billing`, `storage`, optional `garage` waehlen.
5. Owner/Manager/Employee-Ränge erstellen.
6. Permissions setzen.
7. Speichern.

#### Gang erstellen

1. Organisation erstellen.
2. Typ `gang` waehlen.
3. MDT Type `gang` oder `none` waehlen.
4. Module `storage`, `garage`, `radio`, optional `custom` waehlen.
5. Ränge erstellen.
6. Whitelist aktivieren.
7. Speichern.

## 10. Roadmap

### Phase 1: Backend Foundation

Status: vorhanden.

Umfasst:

- Organizations
- Grades
- Members
- Duty
- Modules
- Nexa Callback-System
- oxmysql-basierte Tabellen

### Phase 2: Architektur und Contracts

Status: dieses Dokument.

Aufgaben:

- API-Vertraege dokumentieren.
- Permission-Katalog finalisieren.
- Modul-Konfigurationsschema definieren.
- MDT-Modulmapping definieren.
- UI-Workflows finalisieren.

### Phase 3: Permission Integration

Aufgaben:

- Effektive Permissions pro Spieler und Organisation berechnen.
- Rangpermissions auslesen.
- Permission-Checks als serverseitige API anbieten.
- Audit fuer Permission-Aenderungen.

### Phase 4: JobsCreator Admin UI

Aufgaben:

- Organisationen-Liste.
- Organisations-Wizard.
- Detailseite.
- Grade-Editor.
- Permission-Matrix.
- Modulverwaltung.
- Audit-Ansicht.

### Phase 5: MDT Integration

Aufgaben:

- MDT fragt JobsCreator nach aktiver Organisation.
- MDT liest `organization_type`, `mdt_type`, Module und Permissions.
- MDT baut Navigation dynamisch.
- Police/EMS/Government/Business/Gang/Media werden Module, keine festen Ressourcen.

### Phase 6: Module-Ressourcen anbinden

Aufgaben:

- Garage liest `garage`-Modul.
- Dispatch liest `dispatch`-Modul.
- Billing liest `billing`-Modul.
- Storage liest `storage`-Modul.
- Armory liest `armory`-Modul.
- Evidence liest `evidence`-Modul.
- Medical liest `medical`-Modul.
- Documents/Licenses lesen ihre Module.

### Phase 7: Legacy-Ersatz

Zu ersetzende feste Ressourcen:

- `nexa_lspd`
- `nexa_ems`
- `nexa_government`
- `nexa_weazel`

Diese Ressourcen sollen nicht mehr Hauptsysteme sein. Falls noch Inhalte daraus gebraucht werden, werden sie in generische Module, Templates oder Konfigurationen ueberfuehrt.

### Phase 8: Templates

Aufgaben:

- Police Template
- EMS Template
- Government Template
- Business Template
- Gang Template
- Media Template
- Custom Empty Template

Templates erzeugen Vorschlaege, aber keine Hardcodes.

### Phase 9: Audit und Sicherheit

Aufgaben:

- Alle Admin-Aenderungen auditieren.
- Kritische Aktionen rate-limiten.
- Serverautoritativ validieren.
- Keine UI-Entscheidungen vertrauen.
- Migrationen idempotent halten.

### Phase 10: Ingame Self-Service

Spaeter moeglich:

- Business-Gruendung ingame.
- Bewerbungen.
- Einladungen.
- Member-Onboarding.
- Modul-Upgrades ueber Adminfreigabe.

Self-Service darf nur ueber serverseitige Policies und Permissions funktionieren.

## Architekturentscheidungen

1. Organisationen sind Daten, keine festen Resources.
2. Organisationstypen liefern Defaults, keine Hardcodes.
3. Module liefern Funktionen.
4. Permissions autorisieren Aktionen.
5. Grades gruppieren Permissions.
6. MDT rendert dynamisch.
7. JobsCreator ist die Quelle fuer Organisationen.
8. UI ist nie autoritativ.
9. Legacy-Ressourcen werden durch Templates und Module ersetzt.
10. Erweiterungen muessen ueber Module, Config und Permissions modelliert werden.
