# Shop Studio Architecture

## 1. Vision

Nexa braucht ein eigenes Shop-System, weil Shops im Roleplay mehr sind als feste Kaufpunkte. Shops sind Wirtschaftsknoten, Job- und Organisationswerkzeuge, Blackmarket-Zugaenge, NPC-Interaktionen, Marker, Blips, Lagerbestaende, Ankaufspunkte und Schnittstellen zwischen Items, Economy und JobsCreator.

Das Ziel von `nexa_shops` und dem spaeteren Shop Studio ist ein generisches, serverautoritatives Shop-System. Serveradmins sollen Shops ingame erstellen, bearbeiten, deaktivieren, positionieren und mit Items aus `nexa_items` verknuepfen koennen.

Warum keine festen Shops:

- Feste Shoplisten machen kleine Aenderungen zu Code-Deployments.
- Map-, NPC-, Blip- und Sortimentsdaten verteilen sich sonst ueber mehrere Ressourcen.
- Shops brauchen haeufig dynamische Preise, begrenzte Bestaende und Organisationserloese.
- Neue Jobs, Unternehmen, Events oder Blackmarkets sollen ohne neue Resource entstehen.
- Serveradmins brauchen ein Werkzeug, um Shops im laufenden Betrieb zu testen und anzupassen.

Warum Shops vollstaendig ingame erstellt werden:

- Admins koennen Position, NPC, Marker und Blip direkt am Ort pruefen.
- Shop-Sortimente koennen sofort mit Item Studio abgestimmt werden.
- Preise und Stock koennen ohne Neustart angepasst werden.
- Organisationen aus JobsCreator koennen direkt als Besitzer oder Zugriffsvoraussetzung genutzt werden.
- Economy-Regeln koennen zentral sichtbar gemacht werden.

Shop Studio ist direkt verbunden mit:

- Items: Shops verkaufen oder kaufen Items aus `nexa_items`.
- JobsCreator: Shops koennen Organisationen gehoeren oder Job-/Grade-Voraussetzungen haben.
- Organization: Organisationen koennen eigene Shops, Armories, Jobshops oder Blackmarkets besitzen.
- Economy: Shops erzeugen oder verteilen Geld, Item-Waehrungen, Steuern und Erloese.

Shop Studio ist nicht das Kaufsystem selbst. Es ist das Admin- und Autorensystem fuer Shops. Kauflogik, Inventory, NPCs, Marker und Blips konsumieren spaeter die Shopdefinitionen.

## 2. Benutzerfluss

Der Ziel-Flow fuer Serveradministratoren ist:

1. Serveradmin oeffnet Shop Studio.
2. Shop Studio zeigt die Shopuebersicht.
3. Serveradmin waehlt `Neuer Shop`.
4. Serveradmin waehlt den Shoptyp.
5. Serveradmin setzt Position und Rotation.
6. Serveradmin konfiguriert NPC.
7. Serveradmin konfiguriert Marker.
8. Serveradmin konfiguriert Blip.
9. Serveradmin fuegt Items hinzu.
10. Serveradmin setzt Preise, Buy/Sell-Regeln und Stock.
11. Serveradmin prueft Vorschau und Zugriffsvoraussetzungen.
12. Serveradmin speichert.
13. Shop ist sofort spielbar, sobald die konsumierenden Systeme aktiv sind.

Zielzustand:

Serveradmin

-> Shop Studio

-> Shopuebersicht

-> Neuer Shop

-> Shoptyp

-> Position

-> NPC

-> Marker

-> Blip

-> Items

-> Preise

-> Speichern

-> Shop sofort spielbar

Grundregel: Ein gespeicherter Shop ist eine autoritative Konfiguration. Ob er sichtbar, nutzbar oder kaufbereit ist, haengt spaeter von `enabled`, Position, Zeitfenstern, Permissions, Jobs, Organisationen, Inventory und Economy ab.

## 3. Shop

Ein Shop ist ein konfigurierbarer Verkaufs- oder Ankaufspunkt. Er kann als NPC, Marker, Blip, Organisationsshop, Blackmarket, Government-Schalter, Job-Shop oder rein virtueller Shop existieren.

Pflichtfelder:

- `id`: eindeutige technische ID.
- `name`: technischer Slug, eindeutig und stabil.
- `label`: sichtbarer Anzeigename.
- `shop_type`: fachlicher Shoptyp.
- `enabled`: aktiviert oder deaktiviert den Shop.

Geplante Eigenschaften:

- `organization`: Besitzer- oder Zugrifforganisation.
- `location`: Weltposition.
- `rotation`: Ausrichtung fuer NPC, Marker oder Interaktion.
- `npc`: NPC-Konfiguration.
- `blip`: Map-Blip-Konfiguration.
- `marker`: Marker- oder Zone-Konfiguration.
- `metadata`: freie Zusatzdaten.
- `opening_hours`: Oeffnungszeiten.
- `required_permissions`: benoetigte Permissions.
- `required_modules`: benoetigte JobsCreator-Module.
- `required_job`: benoetigter Job oder Organisationstyp.
- `required_grade`: benoetigter Rang oder Mindestlevel.
- `required_license`: benoetigte Lizenz.

### id

Interne ID fuer technische Referenzen. Admins sollten primaer mit `name` und `label` arbeiten.

### name

Technischer Slug.

Beispiele:

- `legion_general`
- `pillbox_pharmacy`
- `lspd_armory`
- `sandy_blackmarket`
- `bennys_parts`

Der Name sollte nach produktiver Nutzung nicht ohne Migration geaendert werden.

### label

Sichtbarer Name.

Beispiele:

- Legion General Store
- Pillbox Pharmacy
- LSPD Armory
- Sandy Blackmarket
- Bennys Parts Shop

### shop_type

Fachliche Kategorie. Der Typ liefert Defaults, aber keine harte Sonderlogik. Funktionen entstehen durch Items, Economy, Zugriffsvoraussetzungen und Integrationen.

### organization

Organisation aus JobsCreator, die den Shop besitzt oder verwaltet.

Verwendungen:

- Organisation erhaelt Erloese.
- Nur Mitglieder duerfen kaufen.
- Nur bestimmte Ränge duerfen Sortiment verwalten.
- Shop erscheint im MDT oder in Organisationsverwaltung.

### enabled

Deaktivierte Shops:

- werden nicht normal angezeigt.
- erlauben keine Transaktionen.
- bleiben im Admin sichtbar.
- behalten Items, Positionen und Metadaten.

### location

Weltposition des Shops.

Typische Daten:

- x
- y
- z
- heading
- radius
- interior
- routing bucket

### rotation

Ausrichtung fuer NPC, Marker, Props oder Preview.

### npc

NPC-Konfiguration.

Typische Daten:

- model
- coords
- heading
- scenario
- animation
- invincible
- frozen
- interaction radius
- display name

### blip

Blip-Konfiguration.

Typische Daten:

- sprite
- color
- scale
- label
- short range
- route support
- visibility rules

### marker

Marker-Konfiguration.

Typische Daten:

- marker type
- coords
- radius
- color
- draw distance
- interaction text
- zone mode

### metadata

Freie Zusatzdaten fuer Integrationen.

Beispiele:

- shop theme
- legal status
- risk level
- event ID
- custom tags
- default camera angle

### opening_hours

Zeitfenster, in denen Shopzugriff erlaubt ist.

Moegliche Regeln:

- immer offen
- Ingame-Uhrzeit
- Wochentage
- Event-Zeiten
- Organisations-Duty erforderlich

### required_permissions

Permissions, die ein Spieler braucht.

Beispiele:

- `shops.use`
- `shops.blackmarket.access`
- `armory.use`
- `organization.shop.manage`

### required_modules

JobsCreator-Module, die eine Organisation besitzen muss.

Beispiele:

- `billing`
- `armory`
- `storage`
- `medical`
- `documents`

### required_job

Job oder Organisation, die benoetigt wird.

Beispiele:

- `lspd`
- `sams`
- `mechanic`
- `government`

### required_grade

Mindestgrad oder konkrete Rangliste.

Beispiele:

- mindestens Level 30
- nur `chief`, `captain`, `sergeant`
- nur `owner`, `manager`

### required_license

Lizenzvoraussetzung.

Beispiele:

- weapon license
- driver license
- medical license
- business permit

## 4. Shoptypen

### general

Allgemeiner Shop fuer Alltagsitems.

Standardmodule:

- Items
- Inventory
- Economy
- Blip
- Marker oder NPC

Typische Nutzung:

- Supermarkt
- 24/7
- Kiosk
- Tankstellen-Shop

### food

Shop fuer Essen und Getraenke.

Standardmodule:

- Items
- Inventory
- Economy
- Needs

Typische Nutzung:

- Restaurant
- Foodtruck
- Bar
- Cafe

### weapon

Shop fuer Waffen, Munition, Komponenten oder Waffen-Zubehoer.

Standardmodule:

- Items
- Inventory
- Licenses
- Economy
- Audit

Typische Nutzung:

- Ammu-Nation
- Police Armory
- Blackmarket Weapon Dealer

### medical

Shop fuer Medizin, Medkits und medizinische Tools.

Standardmodule:

- Items
- Inventory
- Medical
- JobsCreator

Typische Nutzung:

- Krankenhausapotheke
- EMS Supply
- Pharmacy

### clothing

Shop fuer Kleidung, Uniformen und Accessoires.

Standardmodule:

- Items
- Clothing
- Economy
- Preview

Typische Nutzung:

- Kleidungsladen
- Uniformausgabe
- Gang-Outfit-Shop

### mechanic

Shop fuer Fahrzeugteile, Tools und Tuning-Items.

Standardmodule:

- Items
- Vehicle
- Crafting
- JobsCreator
- Economy

Typische Nutzung:

- Mechanikerteile
- Werkstattshop
- Repair Tools

### organization

Organisationsshop fuer Jobs, Fraktionen, Gangs oder Businesses.

Standardmodule:

- JobsCreator
- Items
- Permissions
- Organization Revenue

Typische Nutzung:

- LSPD Armory
- EMS Supply
- Gang Storage Shop
- Business Internal Shop

### blackmarket

Versteckter oder eingeschraenkter Shop fuer illegale Waren.

Standardmodule:

- Items
- Reputation
- Location Rules
- Economy
- Audit

Typische Nutzung:

- Illegaler Waffenhaendler
- Drogenankauf
- Rare Materials

### government

Shop oder Schalter fuer staatliche Leistungen, Dokumente und Lizenzen.

Standardmodule:

- Documents
- Licenses
- Billing
- JobsCreator
- Economy

Typische Nutzung:

- Lizenzstelle
- Gerichtsschalter
- Permit Office

### job

Shop fuer konkrete Jobs oder Taetigkeiten.

Standardmodule:

- JobsCreator
- Items
- Permissions
- Inventory

Typische Nutzung:

- Jobausruestung
- Werkzeuge
- Starterkits
- Uniformteile

### custom

Freier Shoptyp fuer Server-spezifische Konzepte.

Standardmodule:

- Items
- Economy
- Custom Rules

Typische Nutzung:

- Eventshop
- Token-Shop
- Quest-Shop
- Donator- oder Reward-Shop, falls serverseitig erlaubt

## 5. Shop Items

Shop Items sind Eintraege im Sortiment eines Shops. Sie referenzieren Items aus `nexa_items` und beschreiben Preis-, Stock- und Buy/Sell-Regeln.

Eigenschaften:

- `item`: Item aus `nexa_items`.
- `price`: Preis pro Einheit.
- `buyable`: Spieler duerfen das Item kaufen.
- `sellable`: Spieler duerfen das Item an den Shop verkaufen.
- `currency`: Geldkonto, Standardwaehrung oder Item-Waehrung.
- `stock`: aktueller Bestand.
- `max_stock`: maximaler Bestand.
- `dynamic_price`: dynamische Preisregel.
- `restock`: Auffuellregel.
- `metadata`: Zusatzdaten fuer Shoplogik.
- `quality`: Qualitaets- oder Zustandsregel.

### item

Technischer Item-Slug aus `nexa_items`. Shop Studio darf nur existierende Items zulassen, wenn Item Studio aktiv ist.

### price

Nicht negativer Preis. Preis 0 ist erlaubt fuer freie Jobausruestung, Testitems oder Government-Ausgaben.

### buyable

Wenn true, koennen Spieler das Item kaufen.

### sellable

Wenn true, koennen Spieler das Item an den Shop verkaufen.

### currency

Waehrung fuer Transaktionen.

Moegliche Formen:

- Standardgeld
- Bankkonto
- Organisationskonto
- Item-Waehrung
- Custom Currency

### stock

Aktueller Bestand. `nil` bedeutet unbegrenzt oder nicht verwaltet.

### max_stock

Maximaler Bestand fuer Restock und Ankauf.

### dynamic_price

Preisregel, die Preis anhand von Nachfrage, Stock, Zeit, Reputation oder Organisation anpasst.

### restock

Regel fuer automatische oder manuelle Auffuellung.

Beispiele:

- alle 30 Minuten
- taeglich
- bei Serverstart
- durch Organisationslager
- durch Crafting-Lieferung

### metadata

Zusatzdaten pro Shop-Item.

Beispiele:

- Mindestgrad
- Lizenzanforderung
- Limit pro Spieler
- Sonderpreis
- Eventzeitraum

### quality

Qualitaet des verkauften Items oder Mindestqualitaet beim Ankauf.

## 6. Economy

Shop Studio muss Economy-Regeln beschreiben, aber nicht allein ausfuehren. Transaktionen muessen spaeter durch ein serverautoritatives Economy- und Inventory-System laufen.

### Buy

Buy ist der Kauf eines Shop Items durch einen Spieler.

Server prueft:

- Shop aktiv
- Item aktiv
- buyable true
- Zugriffsvoraussetzungen
- Preis
- Waehrung
- Stock
- Inventory-Kapazitaet
- Rate Limit

### Sell

Sell ist der Verkauf eines Spieleritems an einen Shop.

Server prueft:

- Shop aktiv
- sellable true
- Spieler besitzt Item
- Item ist verkaufbar
- Qualitaet und Metadata passen
- Shop kann Stock aufnehmen
- Auszahlungskonto oder Waehrung

### Dynamic Prices

Dynamische Preise passen sich an.

Moegliche Faktoren:

- Stock niedrig -> Preis steigt
- Stock hoch -> Preis sinkt
- Tageszeit
- Event
- Organisation
- Reputation
- Serverweite Nachfrage

### Limited Stock

Shop hat begrenzte Menge. Kauf reduziert `stock`, Verkauf erhoeht `stock`.

### Infinite Stock

`stock = nil` bedeutet unbegrenzt oder nicht verwaltet. Infinite Stock eignet sich fuer Grundversorgung und Government-Ausgaben.

### Taxes

Steuern koennen auf Kauf oder Verkauf erhoben werden.

Moegliche Ziele:

- Serverkonto
- Government-Konto
- Organisationskonto

### Organization Revenue

Wenn Shop einer Organisation gehoert, kann Umsatz anteilig an diese Organisation gehen.

Beispiele:

- Business Shop zahlt Gewinn an Businesskonto.
- Police Armory hat keine Revenue.
- Government Shop zahlt Fees an Staatskonto.

### NPC Revenue

NPC Revenue ist Umsatz, der keinem Spieler oder keiner Organisation gehoert. Er kann verschwinden, an ein Systemkonto gehen oder in Statistiken landen.

### Server Revenue

Server Revenue ist ein zentraler Sink oder Treasury-Wert fuer Economy-Balancing.

### Custom Currency

Custom Currency sind Waehrungen, die nicht normales Geld sind.

Beispiele:

- Event Tokens
- Reputation Points
- Casino Chips
- Job Credits

### Item Currency

Item Currency nutzt ein Item als Zahlungsmittel.

Beispiele:

- Blackmarket zahlt mit `marked_bills`
- Eventshop nutzt `event_token`
- Gangshop nutzt `reputation_chip`

## 7. Permissions

Shop Studio braucht feingranulare Rechte.

Mindestens:

- `shops.view`
- `shops.create`
- `shops.update`
- `shops.delete`
- `shops.enable`
- `shops.disable`
- `shops.items.manage`
- `shops.npc.manage`
- `shops.marker.manage`
- `shops.blip.manage`
- `shops.import`
- `shops.export`

Weitere empfohlene Permissions:

- `shops.prices.manage`
- `shops.stock.manage`
- `shops.economy.manage`
- `shops.access.manage`
- `shops.preview`
- `shops.audit.view`
- `shops.audit.manage`
- `shops.blackmarket.manage`
- `shops.organization.manage`
- `shops.job.manage`
- `shops.tax.manage`
- `shops.restock.manage`

Regeln:

- UI darf Rechte anzeigen und Buttons ausblenden.
- Server muss jede mutierende Aktion pruefen.
- Loeschen ist getrennt von Deaktivieren.
- Preise und Stock brauchen eigene Rechte.
- Blackmarket-Konfiguration kann eigene Rechte brauchen.
- Organisationsshops koennen zusaetzlich JobsCreator-Permissions nutzen.

## 8. Shop Studio UI

Diese Architektur beschreibt die spaetere UI, implementiert sie aber nicht.

### Hauptnavigation

Seiten:

- Dashboard
- Shopuebersicht
- Kategorien
- Shoptypen
- Sortiment
- Economy
- Preview Lab
- Import/Export
- Audit
- Einstellungen

### Dashboard

Zeigt:

- Anzahl Shops
- aktive Shops
- deaktivierte Shops
- Shops ohne Items
- Shops ohne Position
- Shops ohne Bild/Blip
- Shops mit fehlerhaften Items
- letzte Aenderungen

### Shopuebersicht

Tabellen- oder Kartenansicht.

Spalten:

- Label
- Name
- Typ
- Status
- Position
- NPC
- Marker
- Blip
- Items
- Organisation
- Aktionen

Aktionen:

- Oeffnen
- Duplizieren
- Aktivieren
- Deaktivieren
- Preview
- Export
- Loeschen

### Suche

Sucht ueber:

- Name
- Label
- Shoptyp
- Organisation
- Itemnamen
- Tags
- Location Label

### Filter

Filter:

- Shoptyp
- Enabled
- Hat NPC
- Hat Marker
- Hat Blip
- Hat Items
- Organisation
- Buy/Sell
- Blackmarket
- Job Shop
- Oeffnungszeiten aktiv

### Kategoriebaum

Kategorien strukturieren Shops.

Beispiele:

- City Shops
- Government
- Police
- EMS
- Businesses
- Blackmarket
- Events
- Job Shops

Kategorien sind Admin-Struktur, keine zwingende Gameplay-Regel.

### Shop Editor

Tabs:

- Basics
- Location
- NPC
- Marker
- Blip
- Items
- Economy
- Access
- Preview
- Audit

#### Basics

Felder:

- Name
- Label
- Shop Type
- Enabled
- Organization Owner
- Metadata

#### Location

Funktionen:

- Position setzen
- Position vom Admin uebernehmen
- Rotation setzen
- Radius setzen
- Interior/Bucket setzen

#### NPC

Funktionen:

- NPC aktivieren
- Model waehlen
- Heading setzen
- Scenario waehlen
- Animation waehlen
- Freeze/Invincible toggeln
- Interaction Radius setzen

#### Marker

Funktionen:

- Marker aktivieren
- Marker Type waehlen
- Farbe setzen
- Radius setzen
- Draw Distance setzen
- Interaktionstext setzen

#### Blip

Funktionen:

- Blip aktivieren
- Sprite waehlen
- Farbe waehlen
- Scale setzen
- Label setzen
- Short Range toggeln

#### Items

Funktionen:

- Item hinzufuegen
- Item entfernen
- Preis setzen
- Buyable/Sellable toggeln
- Stock setzen
- Max Stock setzen
- Currency setzen
- Item aus ItemStudio oeffnen

#### Economy

Funktionen:

- Steuerregeln
- Revenue-Ziele
- Dynamic Pricing
- Restock
- Item Currency
- Custom Currency

#### Access

Funktionen:

- Required Permissions
- Required Job
- Required Grade
- Required License
- Required Organization
- Required Modules
- Opening Hours

#### Preview

Zeigt Shop so, wie Spieler ihn spaeter sehen koennten.

#### Audit

Zeigt Aenderungen an Shop, Items, Preisen, Stock und Zugriff.

### Live Preview

Live Preview zeigt:

- NPC-Ansicht
- Marker-Ansicht
- Blip-Ansicht
- Shop-Menue
- Inventory-Auswirkung
- Preisberechnung
- Oeffnungszeiten
- Zugriffsergebnis

### Dialoge

Pflichtdialoge:

- Neuer Shop
- Shop duplizieren
- Shop deaktivieren
- Shop loeschen
- Item hinzufuegen
- Preis bearbeiten
- Stock bearbeiten
- Restock-Regel bearbeiten
- NPC auswaehlen
- Blip konfigurieren
- Import bestaetigen
- Export konfigurieren

### Kontextmenues

Kontextmenues:

- Shop oeffnen
- Shop duplizieren
- Aktivieren
- Deaktivieren
- Zum Shop teleportieren
- Position von Spieler uebernehmen
- Preview oeffnen
- Audit anzeigen
- Loeschen

## 9. Preview

Preview ist das Test- und Sichtpruefungssystem fuer Shop Studio.

### NPC Preview

Zeigt:

- NPC Model
- Position
- Heading
- Scenario
- Interaction Radius
- Name/Label

Testet:

- Model existiert
- NPC steht korrekt
- Heading passt
- Interaktion ist erreichbar

### Marker Preview

Zeigt:

- Marker Type
- Radius
- Farbe
- Draw Distance
- Interaktionstext

Testet:

- Marker sichtbar
- Marker nicht zu gross
- Text passt
- Interaction Radius ist erreichbar

### Blip Preview

Zeigt:

- Sprite
- Farbe
- Scale
- Label
- Short Range Verhalten

Testet:

- Blip ist eindeutig
- Label ist lesbar
- Blip passt zum Shoptyp

### Inventory Preview

Zeigt:

- Shop Items
- Itembilder
- Stack-Regeln
- Gewicht
- Buy/Sell Status
- Currency

Prueft:

- Item existiert in ItemStudio
- Item ist enabled
- Inventory kann Menge aufnehmen
- Item ist handelbar, falls Verkauf aktiv ist

### Preis Preview

Zeigt:

- Basispreis
- Steuer
- Dynamic Price
- Rabatt
- Organisationsanteil
- Serveranteil
- Endpreis

### Oeffnungszeiten Preview

Zeigt:

- aktuelle Serverzeit
- Shop offen/geschlossen
- naechste Oeffnung
- naechste Schliessung
- Sonderregeln

## 10. Roadmap

### Phase 1: Foundation

Status: vorhanden.

Umfasst:

- `nexa_shops` Resource
- `shops` Tabelle
- `shop_items` Tabelle
- Shop API
- Shop Items API
- Nexa Callback-System
- optionale Itempruefung gegen `nexa_items`

### Phase 2: Architektur und Schemas

Status: dieses Dokument.

Aufgaben:

- Shop-Konfigurationsschema definieren.
- NPC-Schema definieren.
- Marker-Schema definieren.
- Blip-Schema definieren.
- Economy-Schema definieren.
- Access-Schema definieren.

### Phase 3: Editor Backend

Aufgaben:

- Permissions erzwingen.
- Audit schreiben.
- Import/Export APIs.
- Preview-/Validation-Endpunkte.
- Reference Checks vor Loeschen.

### Phase 4: Editor

Aufgaben:

- Shopuebersicht.
- Shop Editor.
- Item-Sortiment Editor.
- Economy Editor.
- Access Editor.
- Preview Lab.
- Audit View.

### Phase 5: NPC System

Aufgaben:

- NPC Spawn.
- Cleanup.
- Interaction.
- Scenario/Animation.
- Visibility Rules.

### Phase 6: Marker System

Aufgaben:

- Marker Rendering.
- Zone/Radius Interaction.
- Text UI Integration.
- Cleanup.

### Phase 7: Blip System

Aufgaben:

- Blip-Erzeugung.
- Short Range.
- Dynamic Visibility.
- Shoptyp Defaults.

### Phase 8: Inventory

Aufgaben:

- Shop kauft/verkauft Items.
- Weight und Stack pruefen.
- Metadata unterstuetzen.
- Currency Items pruefen.

### Phase 9: Economy

Aufgaben:

- Buy/Sell Transaktionen.
- Taxes.
- Organization Revenue.
- Server Revenue.
- Custom Currency.
- Item Currency.

### Phase 10: Dynamic Prices

Aufgaben:

- Stock-basierte Preise.
- Nachfrage-basierte Preise.
- Zeitbasierte Preise.
- Eventpreise.

### Phase 11: Organization Integration

Aufgaben:

- Organisationsbesitz.
- Organisationskonto.
- Organisationsrechte.
- Organisationsshops im MDT.

### Phase 12: JobsCreator Integration

Aufgaben:

- Required Modules.
- Required Grade.
- Organization Shop Modul.
- Job Shop Templates.
- Armory/Medical/Mechanic Shops.

### Phase 13: ItemStudio Integration

Aufgaben:

- Item-Auswahl direkt aus ItemStudio.
- Item-Preview im Shop.
- Itemstatus pruefen.
- Item-Referenzen vor Loeschen anzeigen.

## Architekturentscheidungen

1. Shops sind Daten, keine festen Lua-Listen.
2. Shop Studio ist Admin- und Autorensystem, nicht das Kaufsystem.
3. Shoptypen liefern Defaults, keine Hardcodes.
4. Shop Items referenzieren `nexa_items`.
5. Transaktionen muessen serverautoritativ sein.
6. NPCs, Marker und Blips sind Module, keine Pflicht.
7. Economy-Regeln werden konfiguriert und spaeter serverseitig ausgefuehrt.
8. Organisationen und JobsCreator sind direkte Integrationspunkte.
9. UI darf Vorschau liefern, aber keine Transaktion autorisieren.
10. Custom Shops muessen ueber Schemas, Permissions und Audit kontrolliert werden.
