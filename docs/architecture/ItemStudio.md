# Item Studio Architecture

## 1. Vision

Nexa braucht ein eigenes Item-System, weil Items im Roleplay nicht nur technische Inventory-Eintraege sind. Sie sind Gameplay-Objekte, Wirtschaftsgueter, Dokumente, Lizenzen, Waffen, Werkzeuge, Container, Verbrauchsgegenstaende und Bausteine fuer Jobs, Shops, Crafting, Loot, Storage und Organisationen.

Das Ziel von `nexa_items` und dem spaeteren Item Studio ist ein generisches, serverautoritatives Item-System, das Items als Daten modelliert. Serveradmins sollen Items ingame erstellen, bearbeiten, deaktivieren, kategorisieren und testen koennen, ohne Lua-Dateien anzupassen und ohne feste Itemlisten in mehreren Ressourcen zu pflegen.

Warum keine statischen Items:

- Statische Listen erzwingen Deployments fuer einfache Balance-Aenderungen.
- Mehrere Ressourcen koennen auseinanderlaufen, wenn Items mehrfach definiert werden.
- Neue Jobs, Organisationen, Shops, Crafting-Rezepte oder Events brauchen schnell neue Items.
- Serveradmins sollen Items ohne Entwicklerzugriff vorbereiten koennen.
- Custom-Server brauchen eigene Itemtypen, Namen, Bilder, Effekte und Regeln.
- Datenbankbasierte Items koennen deaktiviert, versioniert, importiert und exportiert werden.

Warum Items ingame erstellt werden:

- Admins koennen neue Items sofort testen.
- Balancing wird schneller.
- Eventitems koennen ohne Code-Release entstehen.
- JobsCreator, Shops und Crafting koennen direkt auf neue Items zugreifen.
- Item Studio kann Validierung, Vorschau und Konfliktpruefung zentral anbieten.

Item Studio ist nicht das Inventory selbst. Es ist das Verwaltungs- und Autorensystem fuer Items. Inventory, Crafting, Shops, Drops und Storage konsumieren diese Itemdefinitionen.

## 2. Benutzerfluss

Der Ziel-Flow fuer Serveradministratoren ist:

1. Serveradmin oeffnet Item Studio.
2. Item Studio zeigt die Itemuebersicht.
3. Serveradmin waehlt `Neues Item`.
4. Serveradmin waehlt den Itemtyp.
5. Serveradmin pflegt Eigenschaften.
6. Serveradmin konfiguriert Animation oder Scenario.
7. Serveradmin konfiguriert Effekte.
8. Serveradmin waehlt oder prueft ein Bild.
9. Serveradmin testet die Vorschau.
10. Serveradmin speichert.
11. Item ist sofort fuer angebundene Systeme verfuegbar.

Der Zielzustand:

Serveradmin

-> Item Studio

-> Itemuebersicht

-> Neues Item

-> Typ

-> Eigenschaften

-> Animation

-> Effekte

-> Bild

-> Speichern

-> Sofort verwendbar

Grundregel: Speichern bedeutet nicht automatisch, dass ein Item in jedem System nutzbar ist. Ein Item kann sofort sichtbar sein, aber Inventory, Shops, Crafting, JobsCreator oder Loot muessen es anhand ihrer eigenen Regeln verwenden.

## 3. Item

Ein Item ist die zentrale Definition eines spielbaren oder verwaltbaren Gegenstands.

Pflichtfelder:

- `id`: eindeutige technische ID.
- `name`: technischer Slug, eindeutig, stabil, kleingeschrieben empfohlen.
- `label`: sichtbarer Anzeigename.
- `item_type`: fachlicher Typ.

Basisfelder:

- `description`: Beschreibung fuer UI, Shops, Dokumentation und Tooltips.
- `image_url`: Bildreferenz fuer Inventory, Shops und Preview.
- `weight`: Gewicht in einer serverdefinierten Einheit.
- `stackable`: ob mehrere Einheiten in einem Slot stapelbar sind.
- `max_stack`: maximale Stapelgroesse.
- `usable`: ob das Item eine Benutzung ausloesen darf.
- `tradable`: ob Spieler das Item handeln oder uebergeben duerfen.
- `droppable`: ob Spieler das Item fallenlassen duerfen.
- `enabled`: ob das Item aktiv ist.
- `metadata`: statische Eigenschaften des Item-Typs.
- `use_config`: spaetere Benutzungslogik und Effekte.

Erweiterte Studio-Felder:

- `rarity`: Seltenheit, zum Beispiel common, uncommon, rare, epic, legendary, illegal, restricted.
- `category`: fachliche Gruppe, zum Beispiel food.basic, weapon.handgun, medical.firstaid.
- `tags`: frei waehlbare Tags fuer Suche, Filter und Integrationen.
- `version`: optionale interne Versionsnummer fuer Aenderungshistorie.
- `created_by`: optionaler Admin- oder System-Identifier.
- `updated_by`: optionaler Admin- oder System-Identifier.
- `audit_note`: optionale Begruendung fuer kritische Aenderungen.

### id

`id` ist die interne Datenbank-ID. Sie ist fuer technische Verweise geeignet, aber nicht fuer sichtbare Konfigurationen. UI und Admins arbeiten primaer mit `name`.

### name

`name` ist der stabile technische Key. Er sollte nur Kleinbuchstaben, Zahlen, `_` und `-` enthalten.

Beispiele:

- `sandwich`
- `water_bottle`
- `weapon_pistol`
- `light_armor`
- `mechanic_toolkit`
- `event_token`

Der Name darf nach produktiver Nutzung nur mit Migrations- und Referenzpruefung geaendert werden.

### label

`label` ist der sichtbare Name im Spiel.

Beispiele:

- Sandwich
- Wasserflasche
- Pistole
- Leichte Schutzweste
- Werkzeugkoffer

### description

Beschreibung fuer UI, Shops, Tooltip, Admin-Preview und Dokumentation. Sie darf keine Spiellogik enthalten.

### item_type

Der Itemtyp beschreibt die fachliche Kategorie. Er aktiviert keine harte Sonderlogik allein. Logik entsteht durch `usable`, `metadata`, `use_config`, Module und Permission-Checks.

### image_url

Bildreferenz fuer UI. Kann ein lokaler Asset-Key, ein NUI-Pfad oder spaeter ein verwaltetes Asset sein. Remote-URLs sollten nur erlaubt werden, wenn der Serverbetreiber das bewusst freischaltet.

### weight

Gewicht dient Inventory, Storage, Container, Shops und Crafting. Gewicht muss >= 0 sein. Gewicht 0 ist fuer Dokumente, digitale Keys oder Eventtokens erlaubt.

### stackable und max_stack

`stackable = true` bedeutet, dass mehrere Einheiten in einem Slot liegen koennen. `max_stack` begrenzt die Menge pro Stack.

Regeln:

- Nicht stapelbare Items haben normalerweise `max_stack = 1`.
- Items mit individueller Seriennummer, Haltbarkeit oder Owner-Daten sind meist nicht stapelbar.
- Stapelbare Items sollten nur generische oder stack-kompatible Metadata besitzen.

### usable

`usable = true` bedeutet, dass eine Benutzungsaktion existieren darf. Die konkrete Aktion liegt in `use_config` und wird spaeter von einer Item-Use-Schicht ausgefuehrt.

### tradable

Legt fest, ob Spieler das Item handeln, geben oder verkaufen duerfen. Serverlogik muss diese Regel pruefen.

### droppable

Legt fest, ob das Item in der Welt gedroppt werden darf. Illegale, Quest-, Lizenz- oder Key-Items koennen nicht droppable sein.

### enabled

Deaktivierte Items bleiben in der Datenbank, koennen aber nicht neu erzeugt, gekauft, gecraftet oder benutzt werden. Bestehende Instanzen brauchen spaeter eine definierte Policy:

- behalten, aber nicht nutzen
- automatisch ersetzen
- beim naechsten Laden entfernen
- adminseitig migrieren

### metadata

`metadata` beschreibt Eigenschaften des Items, die nicht direkt eine Benutzung ausloesen. Beispiele sind Seriennummer, Qualitaet, Container-Groesse oder Dokumentdaten.

### use_config

`use_config` beschreibt, was bei Benutzung passieren soll. Es ist eine deklarative Konfiguration, keine direkte Ausfuehrung.

### rarity

Rarity ist fuer UI, Loot, Shops und Balancing. Empfohlene Werte:

- `common`
- `uncommon`
- `rare`
- `epic`
- `legendary`
- `restricted`
- `illegal`
- `event`

### category

Category ist ein hierarchischer fachlicher Pfad.

Beispiele:

- `food.meal`
- `drink.water`
- `weapon.handgun`
- `medical.firstaid`
- `material.metal`
- `document.government`

### tags

Tags sind freie Such- und Integrationsmarker.

Beispiele:

- `police`
- `crafting`
- `shop`
- `illegal`
- `event`
- `ems`
- `starter`

## 4. Itemtypen

### food

Essbare Items. Sie koennen Hunger beeinflussen, Animationen ausloesen und verbraucht werden.

Typische Eigenschaften:

- Hungerwert
- Portionsgroesse
- Haltbarkeit
- Temperatur
- Qualitaet
- Kategorie, zum Beispiel snack, meal, dessert

Typische Module:

- Inventory
- Shops
- Crafting
- Restaurants
- Needs-System

### drink

Trinkbare Items. Sie koennen Durst beeinflussen und optionale Effekte haben.

Typische Eigenschaften:

- Durstwert
- Alkoholgehalt
- Koffeinwert
- Flaschenart
- Temperatur

Typische Module:

- Inventory
- Shops
- Crafting
- Bars
- Needs-System

### weapon

Waffenitems oder Waffenlizenzen als Gegenstand. Die eigentliche Waffenlogik wird spaeter separat serverautoritativ umgesetzt.

Typische Eigenschaften:

- Waffenkategorie
- Kaliber
- Seriennummer
- Komponenten
- Tint
- Zustand
- registrierter Besitzer

Typische Module:

- Inventory
- Armory
- Police Evidence
- Shops
- Licenses

### armor

Schutzwesten, Helme oder andere Schutzgegenstaende.

Typische Eigenschaften:

- Armor-Wert
- Haltbarkeit
- Schutzklasse
- Gewicht
- sichtbares Modell

Typische Module:

- Inventory
- Armory
- Medical
- Shops

### medical

Medizinische Items wie Bandagen, Medkits, Medikamente oder Diagnosewerkzeuge.

Typische Eigenschaften:

- Heal-Wert
- Effektart
- Anwendungsdauer
- Cooldown
- Nebenwirkungen
- EMS-only Flag

Typische Module:

- Inventory
- Medical
- EMS
- Shops
- Crafting

### tool

Werkzeuge fuer Jobs, Crafting, Reparatur, Hacking oder Interaktionen.

Typische Eigenschaften:

- Tool-Kategorie
- Haltbarkeit
- Skill-Anforderung
- Job-Anforderung
- Verbrauch pro Nutzung

Typische Module:

- Inventory
- JobsCreator
- Crafting
- Repair
- Illegal Systems

### document

Dokumente, Formulare, Vertrage, Ausweise oder Zertifikate.

Typische Eigenschaften:

- Dokumenttyp
- Aussteller
- Besitzer
- Gueltigkeit
- Signatur
- Template-ID

Typische Module:

- Inventory
- Documents
- Government
- MDT
- JobsCreator

### license

Lizenzitems oder digitale Lizenzreferenzen.

Typische Eigenschaften:

- Lizenztyp
- Aussteller
- Besitzer
- Gueltig bis
- Status

Typische Module:

- Inventory
- Licenses
- Government
- Police MDT
- Vehicle Dealer

### key

Schluessel fuer Fahrzeuge, Immobilien, Storage, Container oder Systeme.

Typische Eigenschaften:

- Key-Typ
- Ziel-ID
- Besitzer
- Ablaufdatum
- Kopierbarkeit

Typische Module:

- Inventory
- Vehicle Keys
- Housing
- Storage
- JobsCreator

### drug

Illegale oder kontrollierte Substanzen.

Typische Eigenschaften:

- Reinheit
- Menge
- Charge
- Herkunft
- Effekt
- Risiko

Typische Module:

- Inventory
- Illegal Systems
- Crafting
- Evidence
- Shops

### material

Rohstoffe, Komponenten und Crafting-Materialien.

Typische Eigenschaften:

- Materialklasse
- Qualitaet
- Reinheit
- Herkunft
- Crafting-Wert

Typische Module:

- Inventory
- Crafting
- Jobs
- Shops
- Loot

### container

Items, die andere Items enthalten koennen.

Typische Eigenschaften:

- Slot-Anzahl
- Max-Gewicht
- erlaubte Itemtypen
- Besitzer
- Schlossstatus

Typische Module:

- Inventory
- Storage
- Loot
- Shops
- JobsCreator

### ammo

Munition und Magazine.

Typische Eigenschaften:

- Kaliber
- Menge
- Magazin-Typ
- kompatible Waffen
- Zustand

Typische Module:

- Inventory
- Weapons
- Armory
- Shops
- Evidence

### clothing

Kleidung, Uniformen, Accessoires oder Ausruestungsteile.

Typische Eigenschaften:

- Clothing-Slot
- Drawable
- Texture
- Palette
- Geschlecht
- Organisation
- Rangbeschraenkung

Typische Module:

- Inventory
- Clothing
- JobsCreator
- Shops
- Armory

### currency

Alternative Waehrungen, Tokens, Gutscheine oder Eventpunkte.

Typische Eigenschaften:

- Waehrungstyp
- Wert
- Gueltigkeit
- Account-Bindung
- Event-ID

Typische Module:

- Inventory
- Economy
- Shops
- Events
- Crafting

### custom

Freier Typ fuer Server-spezifische Items.

Typische Eigenschaften:

- Custom Tags
- Handler-Key
- Modulbindung
- Event-Kontext
- spezielle Metadaten

Typische Module:

- Inventory
- Custom Resources
- Events
- JobsCreator

## 5. Use Config

`use_config` beschreibt die spaetere Benutzungslogik eines Items. Es ist deklarativ. Item Studio speichert und validiert diese Konfiguration, aber fuehrt sie nicht selbst aus.

Grundprinzipien:

- Server bleibt autoritativ.
- Client darf Animationen und Preview anzeigen, aber keine Effekte autorisieren.
- Jede Wirkung muss serverseitig pruefbar sein.
- Use Config darf mehrere Schritte enthalten.
- Kritische Effekte muessen Logs und Rate Limits unterstuetzen.

### Animation

Beschreibt eine Animation, die beim Benutzen abgespielt wird.

Typische Felder:

- Anim-Dictionary
- Anim-Name
- Flag
- Dauer
- Prop
- Bone
- Offset

### Scenario

Alternative zu Animation. Nutzt ein GTA Scenario.

Typische Felder:

- Scenario-Name
- Dauer
- abbrechbar

### Progress

Progress beschreibt Dauer und Abbruchregeln.

Typische Felder:

- Dauer
- Label
- abbrechbar
- Bewegung erlauben
- Kampf erlauben
- Fahrzeug erlauben

### Cooldown

Cooldown verhindert Spam.

Typische Ebenen:

- pro Spieler
- pro Item
- global
- pro Organisation
- pro Zone

### Consume

Consume reduziert die Itemanzahl nach erfolgreicher Nutzung.

Regeln:

- Nur nach serverseitig erfolgreicher Aktion.
- Bei Abbruch kein Verbrauch, ausser explizit konfiguriert.
- Verbrauch kann Menge > 1 haben.

### Destroy

Destroy entfernt eine konkrete Iteminstanz. Das ist relevant fuer nicht stapelbare Items mit individueller Metadata.

### Create Item

Erzeugt nach Nutzung ein anderes Item.

Beispiele:

- leere Flasche nach Trinken
- geoeffnete Box nach Container-Nutzung
- Rezept erzeugt Ergebnisitem

### Remove Item

Entfernt ein weiteres erforderliches Item.

Beispiele:

- Tool verbraucht Batterie
- Medizin verbraucht Spritze
- Waffe verbraucht Reinigungsset

### Add Hunger

Erhoeht oder senkt Hungerwert.

### Add Thirst

Erhoeht oder senkt Durstwert.

### Armor

Setzt oder erhoeht Armor.

Regeln:

- Maximalwert serverseitig begrenzen.
- Armor-Typ kann Stack- oder Replace-Regeln besitzen.

### Health

Heilt oder schaedigt den Spieler.

Regeln:

- Medizinische Items koennen Job-/Permission-Checks brauchen.
- Revive- oder kritische Heal-Effekte duerfen nicht rein clientseitig sein.

### Stress

Erhoeht oder reduziert Stress.

### Screen Effects

Clientseitige visuelle Effekte.

Beispiele:

- Blur
- Drug effect
- Damage overlay
- Drunk movement

### Sound

Spielt Sounds fuer Nutzung oder Ergebnis.

### Notification

Zeigt Benachrichtigungen bei Start, Erfolg, Fehler oder Abbruch.

### Weapon

Verbindet Item mit spaeterer Waffenlogik.

Moegliche Aktionen:

- Waffe ausruesten
- Waffe registrieren
- Seriennummer pruefen
- Zustand reduzieren

### Ammo

Erlaubt Nachladen oder Munitionserzeugung.

Regeln:

- Kaliber muss kompatibel sein.
- Menge serverseitig pruefen.
- Magazine koennen eigene Metadata besitzen.

### Weapon Tint

Konfiguriert oder setzt Waffenfarbe.

### Weapon Components

Fuegt Komponenten hinzu oder entfernt sie.

Beispiele:

- Suppressor
- Flashlight
- Extended magazine
- Scope

### Vehicle Key

Verknuepft ein Item mit Fahrzeugzugriff.

Typische Daten:

- Plate
- Vehicle ID
- Owner
- Temporary Flag
- Expires At

### Document

Oeffnet, erzeugt oder aktualisiert ein Dokument.

### License

Prueft, erzeugt oder zeigt Lizenzdaten.

### Custom Events

Generischer Erweiterungspunkt fuer serverdefinierte Handler.

Regeln:

- Nur whitelisted Handler-Keys.
- Keine frei editierbaren Eventnamen fuer unsichere Admin-Konfiguration.
- Server validiert Payload.

### Server Events

Server Events duerfen nur ueber erlaubte Handler und mit Permission-/Rate-Limit-Pruefung ausgeloest werden.

### Client Events

Client Events duerfen nur visuelle oder lokale Effekte ausloesen. Sie duerfen nie finalen State autorisieren.

## 6. Metadata

Metadata beschreibt konkrete oder statische Itemdaten. Sie ist generisch, aber muss je Itemtyp validierbar sein.

Beispiele:

- Seriennummer
- Haltbarkeit
- Munition
- Tankfuellung
- Kennzeichen
- Besitzer
- Temperatur
- Qualitaet
- Level
- Farbe
- Skin
- Custom JSON

### Seriennummer

Relevant fuer Waffen, Dokumente, Tools, Fahrzeuge, Evidence oder seltene Items.

### Haltbarkeit

Beschreibt Zustand oder Nutzungsreste.

Beispiele:

- 100 Prozent neue Waffe
- 30 Prozent benutztes Werkzeug
- ablaufende Medizin

### Munition

Bei Waffen oder Magazinen relevant.

### Tankfuellung

Bei Kanistern, Fahrzeugteilen oder Tools relevant.

### Kennzeichen

Bei Vehicle Keys, Fahrzeugdokumenten oder Police Evidence relevant.

### Besitzer

Kann Character ID, Account ID, Organisation ID oder Business ID enthalten.

### Temperatur

Relevant fuer Essen, Trinken, Laborprozesse oder Crafting.

### Qualitaet

Balancing-Wert fuer Crafting, Drogen, Materialien oder Waffen.

### Level

Kann Item-Level, Crafting-Level oder erforderliches Skill-Level beschreiben.

### Farbe

Farbwert fuer Kleidung, Waffen, Items oder UI.

### Skin

Kosmetischer Skin-Key.

### Custom JSON

Freie Erweiterungsdaten. Custom JSON muss durch Schemas oder Handler validiert werden, sobald es Gameplay beeinflusst.

## 7. Permissions

Item Studio braucht fein getrennte Rechte. Keine feste Adminrolle darf implizit alles tun, ohne Permissions.

Empfohlene Permissions:

- `items.view`
- `items.create`
- `items.update`
- `items.delete`
- `items.enable`
- `items.disable`
- `items.import`
- `items.export`
- `items.category.manage`
- `items.type.manage`
- `items.metadata.manage`
- `items.use_config.manage`
- `items.image.manage`
- `items.preview`
- `items.audit.view`
- `items.audit.manage`
- `items.balance.manage`
- `items.rarity.manage`
- `items.tags.manage`
- `items.weapon.manage`
- `items.medical.manage`
- `items.license.manage`
- `items.document.manage`
- `items.custom.manage`

Permission-Regeln:

- Lesen und Bearbeiten sind getrennt.
- Loeschen braucht eine eigene Permission.
- Enable und Disable sind getrennt von Update.
- Import und Export sind eigene Rechte.
- Use Config braucht eigene Rechte, weil dort Gameplay-Effekte entstehen.
- Weapon-, License-, Document- und Medical-Konfigurationen koennen zusaetzliche Rechte brauchen.
- UI darf Buttons verstecken, Server muss trotzdem pruefen.

## 8. Item Studio UI

Diese Architektur beschreibt die spaetere UI, implementiert sie aber nicht.

### Hauptnavigation

Seiten:

- Dashboard
- Itemuebersicht
- Kategorien
- Typen
- Import/Export
- Preview Lab
- Audit
- Einstellungen

### Dashboard

Zeigt:

- Gesamtzahl Items
- aktive Items
- deaktivierte Items
- Items ohne Bild
- nutzbare Items ohne Use Config
- fehlerhafte Konfigurationen
- letzte Aenderungen

### Itemuebersicht

Zentrale Tabelle oder Grid-Ansicht.

Spalten:

- Bild
- Label
- Name
- Typ
- Kategorie
- Rarity
- Gewicht
- Stack
- Usable
- Enabled
- Tags
- Aktionen

Aktionen:

- Oeffnen
- Duplizieren
- Aktivieren
- Deaktivieren
- Exportieren
- Loeschen

### Suche

Sucht ueber:

- Name
- Label
- Description
- Type
- Category
- Tags
- Metadata-Schluessel

### Filter

Filter:

- Itemtyp
- Kategorie
- Rarity
- Enabled
- Usable
- Stackable
- Tradable
- Droppable
- Hat Bild
- Hat Metadata
- Hat Use Config
- Tags

### Kategoriebaum

Der Kategoriebaum strukturiert Items.

Beispiele:

- Food
  - Meals
  - Snacks
  - Ingredients
- Weapons
  - Handguns
  - Rifles
  - Melee
- Medical
  - First Aid
  - Drugs
  - Tools

Kategorien sind Verwaltungshilfen, keine zwingenden Gameplay-Regeln.

### Item Editor

Tabs:

- Basics
- Type
- Metadata
- Use Config
- Image
- Preview
- Integrations
- Audit

#### Basics

Felder:

- Name
- Label
- Description
- Enabled
- Category
- Rarity
- Tags

#### Type

Felder:

- Item Type
- Stackable
- Max Stack
- Weight
- Tradable
- Droppable
- Usable

Der Typwechsel muss warnen, wenn vorhandene Metadata oder Use Config nicht mehr passt.

#### Metadata

Editor fuer generische Metadata.

Ansichten:

- Formular fuer bekannte Felder
- JSON-Ansicht fuer Experten
- Schema-Validierung
- Fehlerliste

#### Use Config

Editor fuer Benutzungslogik.

Bereiche:

- Progress
- Animation oder Scenario
- Requirements
- Effects
- Consume/Destroy
- Created Items
- Events
- Notifications

#### Image

Bildverwaltung.

Funktionen:

- Bild aus Asset-Bibliothek waehlen
- Bildpfad pruefen
- Vorschau in verschiedenen Groessen
- Platzhalter anzeigen

#### Preview

Zeigt das Item so, wie es in Inventory, Shop, Loot oder Storage erscheinen koennte.

#### Integrations

Zeigt, wo das Item verwendet wird.

Beispiele:

- Shops
- Crafting-Rezepte
- Loot-Tabellen
- JobsCreator Module
- Storage Rules

#### Audit

Zeigt Aenderungen:

- erstellt
- aktualisiert
- aktiviert
- deaktiviert
- importiert
- exportiert
- geloescht

### Live Preview

Live Preview aktualisiert sich beim Bearbeiten.

Ansichten:

- Inventory Slot
- Tooltip
- Shop Card
- Drop Label
- Document View
- Weapon/Armor Summary

### Dialoge

Pflichtdialoge:

- Neues Item
- Item duplizieren
- Item deaktivieren
- Item loeschen
- Import bestaetigen
- Export konfigurieren
- Metadata-Feld hinzufuegen
- Use Effect hinzufuegen
- Bild auswaehlen

### Kontextmenues

Kontextmenues:

- Oeffnen
- Duplizieren
- Aktivieren
- Deaktivieren
- In Preview Lab testen
- Exportieren
- Audit anzeigen
- Loeschen

## 9. Item Preview

Item Preview ist das Test- und Sichtpruefungssystem des Item Studios.

### Bilder

Bilder werden in mehreren Zielgroessen dargestellt:

- Inventory Slot
- Tooltip
- Shop Card
- Storage Row
- Crafting Result
- Drop Marker

Regeln:

- Fehlende Bilder zeigen einen Platzhalter.
- Ungueltige Pfade werden markiert.
- Bilder duerfen Layout nicht sprengen.
- Transparente PNGs werden bevorzugt.
- Preview zeigt dunklen und hellen Hintergrund.

### Animationen testen

Animationstest ist spaeter ein geschuetzter Adminmodus.

Funktionen:

- Animation laden
- Scenario testen
- Prop anzeigen
- Dauer pruefen
- Abbruchverhalten simulieren
- Fehler anzeigen, wenn Animation fehlt

Der Test darf keine echten Effekte ausloesen, ausser der Admin aktiviert ausdruecklich einen sicheren Testmodus.

### Effekte simulieren

Effektsimulation zeigt erwartete Resultate ohne echten Gameplay-State dauerhaft zu veraendern.

Simulierbar:

- Hunger
- Thirst
- Armor
- Health
- Stress
- Consume
- Created Items
- Removed Items
- Cooldown
- Notifications
- Sounds
- Screen Effects

Serverseitige Simulation muss spaeter dieselben Validierungen wie echte Nutzung verwenden.

### Preview Lab

Preview Lab erlaubt:

- Item auswaehlen
- Menge setzen
- Metadata-Beispiel setzen
- Use Config testen
- Zielsystem waehlen
- Ergebnisbericht anzeigen

Zielsysteme:

- Inventory
- Shop
- Crafting
- Loot
- Storage
- JobsCreator

## 10. Roadmap

### Phase 1: Backend Foundation

Status: vorhanden.

Umfasst:

- `nexa_items` Resource
- `items` Tabelle
- Create/Get/List/Update/Enable/Delete API
- Nexa Callback-System
- JSON-Felder fuer Metadata und Use Config

### Phase 2: Architektur und Schemas

Status: dieses Dokument.

Aufgaben:

- Itemtyp-Schemas definieren.
- Metadata-Schemas definieren.
- Use Config-Schemas definieren.
- Permission-Katalog finalisieren.
- Import-/Export-Format definieren.

### Phase 3: Editor Backend

Aufgaben:

- Permission Checks erzwingen.
- Audit schreiben.
- Import/Export APIs.
- Category APIs.
- Tag APIs.
- Preview-/Simulation-Endpoints.

### Phase 4: Item Studio Editor

Aufgaben:

- Itemuebersicht.
- Item Editor.
- Metadata Editor.
- Use Config Editor.
- Image Preview.
- Live Preview.
- Audit View.

### Phase 5: Inventory Integration

Aufgaben:

- Inventory liest Itemdefinitionen.
- Stack-Regeln anwenden.
- Weight-Regeln anwenden.
- Enabled-Regeln anwenden.
- Metadata pro Iteminstanz unterstuetzen.

### Phase 6: Item Use System

Aufgaben:

- Use Config serverseitig ausfuehren.
- Animation/Progress clientseitig anzeigen.
- Effekte serverseitig autorisieren.
- Cooldowns.
- Consume/Destroy/Create.

### Phase 7: Crafting

Aufgaben:

- Crafting-Rezepte lesen Items.
- Materialanforderungen.
- Qualitaet und Level.
- Output-Items.
- JobsCreator- und Organisationsbindung.

### Phase 8: Loot

Aufgaben:

- Loot-Tabellen.
- Drop-Chancen.
- Rarity.
- Zonenbindung.
- Event-Loot.

### Phase 9: Shops

Aufgaben:

- Shop-Sortimente.
- Preise.
- Stock.
- Organisationseigene Shops.
- Lizenz- und Permission-Pruefung.

### Phase 10: Drops

Aufgaben:

- Welt-Drops.
- Drop-Ownership.
- Despawn-Regeln.
- Droppable-Regeln.
- Audit fuer kritische Drops.

### Phase 11: Storage

Aufgaben:

- Storage nutzt Weight und Stack.
- Container-Items.
- Organisationslager.
- Housing Storage.
- Evidence Storage.

### Phase 12: JobsCreator Integration

Aufgaben:

- Organisationen koennen Itemzugriff konfigurieren.
- Armory nutzt Items.
- Medical nutzt Items.
- Documents/Licenses nutzen Items.
- Garage/Keys nutzen Key-Items.
- Shops und Storage koennen organisationsgebunden sein.

### Phase 13: Balance und Operations

Aufgaben:

- Item-Aenderungen auditieren.
- Live-Server Warnungen bei kritischen Aenderungen.
- Referenzpruefung vor Loeschen.
- Bulk-Import.
- Bulk-Export.
- Staging und Publish Workflow.

## Architekturentscheidungen

1. Items sind Daten, keine statischen Lua-Listen.
2. Item Studio ist Admin- und Autorensystem, nicht Inventory.
3. Itemtyp liefert Struktur, aber keine Hardcodes.
4. Use Config beschreibt Benutzung deklarativ.
5. Metadata beschreibt konkrete Itemdaten.
6. Server autorisiert jede kritische Wirkung.
7. UI darf Vorschau und Komfort liefern, aber nie finalen State entscheiden.
8. Inventory, Crafting, Shops, Loot, Drops und Storage konsumieren Itemdefinitionen.
9. JobsCreator kann Items ueber Module und Organisationen nutzen.
10. Custom-Erweiterungen muessen ueber Schemas, Handler und Permissions kontrolliert werden.
