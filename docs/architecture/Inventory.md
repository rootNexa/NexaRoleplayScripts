# Nexa Inventory Architecture

## 1. Vision

Nexa braucht ein eigenes Inventory, weil Inventare im Roleplay mehr sind als eine Liste von Items. Sie sind Besitzmodell, Sicherheitsgrenze, Wirtschaftsschnittstelle, Storage-System, Shop-Grundlage, Crafting-Quelle, Beweisverwaltung, Fahrzeuglager, Organisationswerkzeug und UI-Erlebnis.

Das Ziel von `nexa_inventory` ist ein generisches, serverautoritatives Inventory-System, das alle Gegenstaende als Instanzen verwaltet und Itemdefinitionen aus `nexa_items` konsumiert. Item Studio definiert, was ein Item ist. Inventory entscheidet, wem welche Iteminstanz gehoert, wo sie liegt, wie viele davon existieren und welche Instanz-Metadaten daran haengen.

Warum Nexa ein eigenes Inventory besitzt:

- Nexa hat keine QBCore/Qbox/ESX-Abhaengigkeit und braucht daher ein eigenes Ownership- und Validierungsmodell.
- Items sollen aus Item Studio kommen, nicht aus statischen Lua-Listen.
- Organisationen, Shops, Crafting, Drops, Storage und JobsCreator muessen dieselben Iteminstanzen verstehen.
- Serveradmins sollen Spaeter Inventarregeln konfigurieren koennen, ohne Kerncode umzuschreiben.
- Sicherheit, Auditing und Anti-Abuse muessen zum Nexa-Framework passen.
- Spieleraktionen duerfen nicht clientautoritativ sein.

Warum keine festen Slots:

- Verschiedene Inventorytypen brauchen verschiedene Layouts: Spieler, Fahrzeug, Storage, Shop, Container und Evidence.
- Slotanzahl kann von Rucksack, Kleidung, Job, Fahrzeugklasse, Containergroesse oder Serverregel abhaengen.
- Manche Inventare arbeiten primaer nach Gewicht, andere nach Slots, andere nach beidem.
- Container koennen eigene Limits haben.
- UI und Backend duerfen Slots nicht als starre globale Matrix betrachten.

Warum Inventory vollstaendig serverautoritativ ist:

- Der Client darf nur Absichten senden, zum Beispiel "verschiebe Item X nach Slot Y".
- Der Server prueft Besitz, Distanz, Zustand, Permission, Gewicht, Slots, Cooldown und Itemregeln.
- Jede Mutation wird serverseitig berechnet und gespeichert.
- UI-Zustand ist nur Darstellung, nie Quelle der Wahrheit.
- Exploits wie Item-Duplizierung, Ghost Items, fremde Storage-Zugriffe oder manipulierte Mengen werden am Server verhindert.

Warum Items ueber Item Studio definiert werden:

- Item Studio ist die Quelle fuer `name`, `label`, `item_type`, Gewicht, Stackregeln, Nutzbarkeit, Bild und Use Config.
- Inventory speichert keine fachliche Itemdefinition doppelt.
- Ein Item kann in mehreren Systemen konsistent genutzt werden: Shops, Crafting, Drops, Storage, MDT, JobsCreator.
- Aenderungen an Itemdefinitionen wirken zentral, waehrend Iteminstanzen ihre individuellen Metadaten behalten.

Inventory ist nicht Item Studio. Inventory ist nicht Shop Studio. Inventory ist die Besitz- und Instanzschicht, auf der diese Systeme aufbauen.

## 2. Benutzerfluss

Der Ziel-Flow fuer Spieler ist:

1. Spieler oeffnet Inventory.
2. Inventory laedt serverseitig die erlaubten Inventare.
3. Spieler sieht eigene Items.
4. Spieler waehlt ein Item.
5. Spieler kann es benutzen, verschieben, teilen, uebergeben, droppen oder in einen Container legen, wenn Regeln es erlauben.
6. Spieler oeffnet Container, Storage, Fahrzeug oder Organisationinventar.
7. Spieler verschiebt Items zwischen erlaubten Inventaren.
8. Spieler legt Items als Drop auf den Boden.
9. Spieler nutzt Organisationslager, Shop-Inventory oder Crafting-Materialien.
10. Server validiert jede Aktion und sendet den neuen Zustand zurueck.

Zielzustand:

Spieler

-> Inventory

-> Items

-> Benutzen

-> Verschieben

-> Container

-> Storage

-> Drop

-> Organisation

-> Shops

-> Crafting

Grundregel: Der Spieler sieht nur Inventare, fuer die er im aktuellen Kontext berechtigt ist. Ein geoeffnetes zweites Inventar bedeutet nicht automatisch, dass alle Items bewegt werden duerfen.

## 3. Inventory

### Inventory

Ein Inventory ist ein autoritativer Besitzerraum fuer Items. Es gehoert zu einem `owner_type` und einem `owner_id`.

Beispiele:

- Charakterinventar eines Spielers.
- Kofferraum eines Fahrzeugs.
- Lager einer Organisation.
- Shop-Lagerbestand.
- Drop auf dem Boden.
- Container innerhalb eines anderen Inventars.

Ein Inventory hat:

- technische ID
- Owner Type
- Owner ID
- sichtbares Label
- maximales Gewicht
- maximale Slots
- Metadaten
- Items
- Zugriffsregeln
- Lebenszyklus

### Inventory Instance

Eine Inventory Instance ist die konkrete Laufzeit- und Datenbankinstanz eines Inventars. Die Definition "Fahrzeugkofferraum" ist abstrakt. Der Kofferraum von Kennzeichen `NEXA123` ist eine konkrete Instance.

Inventory Instances koennen permanent oder temporaer sein:

- Permanent: Charakter, Fahrzeug, Organisation, Storage, Evidence.
- Temporaer: Drop, temporärer Container, Loot-Cache.

### Inventory Item

Ein Inventory Item ist eine konkrete Instanz eines Itemnamens in einem Inventory.

Es enthaelt:

- Inventory Item ID
- Inventory ID
- Item Name aus `nexa_items`
- Slot
- Menge
- Instanz-Metadata
- Erstellungszeit
- Aktualisierungszeit

### Slot

Ein Slot ist eine optionale Position innerhalb eines Inventars. Slots sind nicht global fest. Sie gehoeren zu einer Inventory Instance.

Slotregeln:

- Ein Slot kann leer sein.
- Ein Slot kann einen Stack enthalten.
- Ein Item kann ohne Slot existieren, wenn ein System nur Gewicht oder Listen nutzt.
- Die UI darf Slots darstellen, aber der Server entscheidet, ob der Slot gueltig ist.

### Weight

Weight beschreibt die Last eines Items oder Inventars. Das Gewicht eines Stacks ergibt sich aus Itemgewicht mal Menge, plus optionale Instanz-Metadaten.

Weight muss serverseitig berechnet werden. Der Client darf Werte anzeigen, aber nicht bestimmen.

### Container

Ein Container ist ein Item, das ein eigenes Inventory besitzen kann. Beispiele sind Rucksack, Tasche, Koffer, Waffenkiste oder Beweiskiste.

Container verbinden Iteminstanz und Inventory Instance:

- Iteminstanz: "Rucksack mit Seriennummer X".
- Inventory Instance: "Inhalt dieses Rucksacks".

### Metadata

Metadata trennt Definition und Instanz:

- Itemdefinition: Standarddaten aus Item Studio.
- Inventory Item Metadata: konkrete Werte einer Instanz.
- Inventory Metadata: Kontextdaten des Inventars.

Metadata ist generisch, aber darf nur serverseitig validiert und veraendert werden.

### Ownership

Ownership beantwortet: Wem gehoert ein Inventory oder eine Iteminstanz?

Moegliche Ownership-Ebenen:

- technischer Besitzer: `owner_type`, `owner_id`
- Zugriff: wer darf oeffnen
- Verwaltung: wer darf verschieben oder loeschen
- Audit: wer hat zuletzt geaendert
- Kontext: Fahrzeug, Organisation, Drop-Zone, Haus, Shop

Ownership ist nicht immer gleich Zugriff. Ein Organisationslager gehoert der Organisation, kann aber von Mitgliedern mit Permission genutzt werden.

## 4. Inventorytypen

### player

Beschreibung: Technisches Player-Session-Inventar.

Besitzer: Server-Player-ID oder Account-Identifier.

Speicherung: Nur verwenden, wenn bewusst an die Session gebunden. Langfristig nicht als Hauptinventar fuer Roleplay-Besitz.

Sichtbarkeit: Nur fuer den aktiven Spieler und berechtigte Admins.

### character

Beschreibung: Hauptinventar eines Charakters.

Besitzer: Character ID.

Speicherung: Permanent.

Sichtbarkeit: Spieler selbst, Admins, Kontrollsysteme wie Police/MDT nur bei passenden Regeln.

### vehicle

Beschreibung: Fahrzeuglager, Kofferraum, Handschuhfach oder Spezialstorage.

Besitzer: Fahrzeug-Identifier, Kennzeichen oder Vehicle ID.

Speicherung: Permanent fuer persistente Fahrzeuge, temporaer fuer gespawnte Fahrzeuge.

Sichtbarkeit: Besitzer, Schluesselinhaber, Jobs mit Permission, Admins.

### organization

Beschreibung: Lager einer Organisation, Fraktion, Gang, Firma oder Behoerde.

Besitzer: Organization ID aus JobsCreator.

Speicherung: Permanent.

Sichtbarkeit: Organisationsmitglieder mit passenden Permissions und Modulen.

### storage

Beschreibung: Generisches Lager fuer Haeuser, Apartments, Lagerraeume, Schliessfaecher oder Weltobjekte.

Besitzer: Storage ID, Property ID oder Custom Identifier.

Speicherung: Permanent oder temporaer je nach Storage-Typ.

Sichtbarkeit: Konfigurierbar ueber Keys, Permissions, Besitz, Distanz und Instanz.

### shop

Beschreibung: Lagerbestand eines Shops.

Besitzer: Shop ID aus Shop Studio.

Speicherung: Permanent, wenn Stock limitiert ist. Virtuell, wenn Stock unendlich ist.

Sichtbarkeit: Shop-System, Shop-Betreiber, Admins. Spieler sehen nur kaufbare oder verkaufbare Positionen.

### drop

Beschreibung: Bodeninventar oder Welt-Drop.

Besitzer: Drop ID.

Speicherung: Temporaer mit Lebensdauer, optional persistent bei Serverneustart.

Sichtbarkeit: Spieler in Reichweite und in derselben Instanz.

### container

Beschreibung: Inhalt eines Container-Items.

Besitzer: Inventory Item ID oder Container Instance ID.

Speicherung: Permanent, solange die Container-Iteminstanz existiert.

Sichtbarkeit: Wer den Container besitzt, oeffnet oder durchsucht.

### mailbox

Beschreibung: Postfach, Lieferbox oder administrative Zustellung.

Besitzer: Character ID, Account ID, Organisation ID oder Property ID.

Speicherung: Permanent bis Abholung oder Ablauf.

Sichtbarkeit: Empfaenger und Admins.

### evidence

Beschreibung: Beweis- und Asservatenlager.

Besitzer: Organisation, Case ID oder Evidence Box ID.

Speicherung: Permanent mit Audit-Pflicht.

Sichtbarkeit: Police-/Government-Organisationen mit Evidence-Permissions.

### custom

Beschreibung: Erweiterungspunkt fuer serverspezifische Systeme.

Besitzer: frei definierter Identifier.

Speicherung: nach Custom-Regel.

Sichtbarkeit: nach Custom-Regel, aber immer serverseitig validiert.

## 5. Item Instanzen

Itemdefinition ist nicht Iteminstanz.

Itemdefinition:

- kommt aus `nexa_items`
- beschreibt den Typ und Standardwerte
- ist fuer alle Instanzen gleich
- wird durch Item Studio verwaltet

Iteminstanz:

- liegt in einem Inventory
- besitzt Menge, Slot und Metadata
- kann individuelle Eigenschaften haben
- kann auditierbar bewegt, benutzt, zerstoert oder erzeugt werden

Beispiele:

### Waffe

Definition: `weapon_pistol`

Instanz-Metadata:

- Seriennummer
- Munition
- Zustand
- Waffenkomponenten
- Tint
- registrierter Besitzer
- Evidence-Status

### Seriennummer

Seriennummern gehoeren zur Instanz, nicht zur Definition. Zwei Pistolen koennen dieselbe Definition haben, aber unterschiedliche Seriennummern.

### Munition

Munition kann als eigenes Item existieren oder als Metadata an einer Waffe haengen. Die Zielarchitektur soll beides erlauben, aber ein System muss pro Waffentyp entscheiden, welche Variante gilt.

### Haltbarkeit

Haltbarkeit ist Instanz-Metadata. Ein Sandwich kann frisch oder verdorben sein. Ein Werkzeug kann abgenutzt sein.

### Tankfuellung

Kanister oder Fuel-Container speichern Tankfuellung als Metadata.

### Dokument

Dokumente nutzen dieselbe Itemdefinition, speichern aber Aussteller, Empfaenger, Text, Signatur, Ablaufdatum und Template-Version als Metadata.

### Schluessel

Schluessel speichern Zieltyp und Ziel-ID als Metadata, zum Beispiel Fahrzeug, Haus, Lager oder Container.

### Kleidung

Kleidung speichert Komponenten, Farbe, Skin, Zustand und Besitzer als Metadata.

### Container

Container-Items speichern einen Verweis auf ihre Container-Inventory-Instance oder die Daten, aus denen diese Instance erzeugt wird.

## 6. Container

Container sind Items mit eigenem Inhalt. Sie ermoeglichen verschachtelte Inventare, muessen aber harte Grenzen haben.

### Rucksaecke

Rucksaecke erweitern das tragbare Inventar oder stellen ein eigenes Container-Inventar bereit. Sie koennen Gewicht, Slots und erlaubte Itemtypen begrenzen.

### Taschen

Taschen sind kleine Container fuer Dokumente, Geld, Tools oder persoenliche Gegenstaende.

### Koffer

Koffer koennen groessere Slots haben, aber Gewichtslimits und Transportregeln brauchen.

### Waffenkisten

Waffenkisten koennen nur Waffen, Munition und Komponenten erlauben. Zugriff kann Organisations- oder Permission-basiert sein.

### Beweiskisten

Beweiskisten sind auditpflichtig. Jede Bewegung muss nachvollziehbar sein.

### Lagerboxen

Lagerboxen sind generische Container fuer Storage-Systeme.

### Container im Container

Container in Containern sind erlaubt, wenn die Serverregel es zulaesst. Ohne Limits fuehrt das zu unendlicher Rekursion, unklarer Gewichtsermittlung und Exploit-Risiken.

### Grenzen

Pflichtgrenzen:

- maximale Container-Tiefe
- maximales rekursives Gewicht
- verbotene Self-Referenzen
- verbotene Zyklen
- erlaubte Owner Types
- erlaubte Itemtypen pro Container
- Zugriffssperren bei offenem Container

### Rekursion

Rekursion muss serverseitig berechnet und gecacht werden. Ein Container darf nie indirekt sich selbst enthalten. Bewegungen, die einen Zyklus erzeugen wuerden, werden abgelehnt.

## 7. Gewicht

### Weight

Jedes Item hat ein Basisgewicht aus Item Studio. Inventory berechnet daraus Instanz- und Gesamtgewicht.

Gesamtgewicht eines Stacks:

- Basisgewicht mal Menge
- plus optionale Metadata-Modifikatoren
- plus Containerinhalt, wenn das Item ein Container ist und rekursives Gewicht aktiv ist

### Slots

Slots begrenzen Positionen, nicht Gewicht. Ein Inventar kann 20 Slots und 50 kg erlauben. Beide Limits koennen gleichzeitig gelten.

### Stacking

Stacking basiert auf Itemdefinition und Metadata-Kompatibilitaet.

Items duerfen nur stacken, wenn:

- `stackable` true ist
- `item_name` identisch ist
- relevante Metadata gleich oder stack-kompatibel ist
- `max_stack` nicht ueberschritten wird
- Zielslot frei oder kompatibel ist

### Max Stack

`max_stack` kommt aus Item Studio. Inventory darf zusaetzliche Limits setzen, zum Beispiel pro Container oder per Gameplay-Regel.

### Container Weight

Container haben eigenes Gewicht und Inhalt. Ein leerer Rucksack wiegt anders als ein voller Rucksack.

### Recursive Weight

Recursive Weight addiert Inhalte verschachtelter Container. Dieses Verhalten muss konfigurierbar sein, aber der sichere Standard ist: Containerinhalt zaehlt zum Gewicht des tragenden Inventars.

## 8. Permissions

Permissions sind generisch und sollen nicht an feste Jobs gebunden sein. JobsCreator, Organisationen, Adminsysteme und Gameplay-Ressourcen vergeben Berechtigungen.

Mindestpermissions:

- `inventory.open`: eigenes oder erlaubtes Inventar oeffnen.
- `inventory.use`: Item benutzen.
- `inventory.move`: Items innerhalb erlaubter Inventare bewegen.
- `inventory.drop`: Items droppen.
- `inventory.give`: Items an andere Spieler uebergeben.
- `inventory.admin`: administrative Aktionen.
- `inventory.inspect`: fremdes Inventar ansehen.
- `inventory.storage`: Storage oeffnen.
- `inventory.organization`: Organisationslager nutzen.
- `inventory.evidence`: Evidence-Lager nutzen.
- `inventory.vehicle`: Fahrzeuglager nutzen.
- `inventory.container`: Container oeffnen.
- `inventory.clear`: Inventar leeren.
- `inventory.create`: Inventar erzeugen.
- `inventory.delete`: Inventar entfernen.
- `inventory.item.add`: Items serverseitig hinzufuegen.
- `inventory.item.remove`: Items serverseitig entfernen.
- `inventory.item.set_amount`: Mengen setzen.
- `inventory.audit.view`: Audit-Historie ansehen.

Permission-Pruefung erfolgt serverseitig pro Aktion. Der Client darf Permissions anzeigen, aber nicht durchsetzen.

## 9. Inventory UI

Inventory UI ist ein eigenes spaeteres Frontend, nicht Teil der aktuellen Foundation.

### Kompletter Aufbau

Die UI besteht aus:

- linker Inventory-Seite
- rechter Kontext- oder Zielseite
- Header mit Gewicht, Slots und Suchfeld
- Itemgrid oder Itemliste
- Quick Slots
- Tooltip
- Kontextmenue
- Detailpanel
- Filter und Sortierung
- Aktionsleiste

### Linke Seite

Die linke Seite zeigt standardmaessig das eigene Charakterinventar:

- Gewicht
- Slotnutzung
- Itemgrid
- Quick Slots
- Suche
- Sortierung
- aktive Filter

### Rechte Seite

Die rechte Seite zeigt das geoeffnete Zielinventar:

- Container
- Fahrzeug
- Storage
- Organisation
- Shop
- Drop
- Evidence

Wenn kein Zielinventar offen ist, kann rechts eine Item-Preview oder Quick-Actions erscheinen.

### Container

Container werden als zweite Seite, Modal oder eingebettetes Panel geoeffnet. Die UI muss klar zeigen, welcher Container aktiv ist und wie tief die Verschachtelung ist.

### Kontextmenue

Context-Aktionen pro Item:

- benutzen
- verschieben
- teilen
- geben
- droppen
- ansehen
- umbenennen, falls erlaubt
- oeffnen, falls Container
- entladen, falls Waffe
- reparieren, falls System vorhanden

### Tooltip

Tooltips zeigen:

- Bild
- Label
- Beschreibung
- Typ
- Gewicht
- Menge
- Zustand
- Seltenheit
- wichtige Metadata
- erlaubte Aktionen

### Suche

Suche filtert nach:

- Name
- Label
- Typ
- Kategorie
- Tags
- Metadata-Auszug

### Filter

Filter:

- Typ
- Kategorie
- Seltenheit
- Benutzbar
- Stackable
- Zustand
- Besitzer
- Illegal/Restricted

### Sortieren

Sortierung:

- Slot
- Name
- Gewicht
- Menge
- Typ
- Seltenheit
- zuletzt erhalten

### Drag & Drop

Drag & Drop ist nur UI-Absicht. Der Server bestaetigt oder lehnt ab.

Regeln:

- optimistische UI nur mit Rollback
- kein lokales Erzeugen oder Loeschen von Items
- serverseitige Slot-, Weight- und Permission-Pruefung
- klare Fehlermeldung bei Ablehnung

### Mehrfachauswahl

Mehrfachauswahl erlaubt Bulk-Aktionen:

- verschieben
- droppen
- verkaufen
- lagern
- exportieren fuer Admins

Jede Bulk-Aktion wird serverseitig als Transaktion oder als kontrollierte Batch-Verarbeitung behandelt.

### Quick Slots

Quick Slots sind Verknuepfungen auf Inventory Items. Sie speichern keine Kopie des Items.

Regeln:

- Quick Slot referenziert Iteminstanz.
- Wenn Item verschwindet, wird Quick Slot ungueltig.
- Benutzung laeuft ueber Use System und Servervalidierung.

## 10. Use System

Das Use System fuehrt Itemnutzung aus. Es konsumiert `use_config` aus Item Studio und Instanz-Metadata aus Inventory.

### Animation

Animationen werden aus Use Config gelesen. Der Server autorisiert die Nutzung, der Client spielt Animation nur nach Freigabe.

### Scenario

Scenarios sind alternative Nutzungsformen, zum Beispiel Essen, Trinken, Reparieren oder medizinische Behandlung.

### Progress

Progress beschreibt Dauer und Abbruchregeln:

- Dauer
- Bewegung erlaubt
- Kampf erlaubt
- Fahrzeug erlaubt
- Abbruch bei Schaden
- Abbruch bei Distanz

### Cooldown

Cooldowns koennen pro Item, Spieler, Itemtyp oder Use Action gelten. Cooldowns werden serverseitig gespeichert oder berechnet.

### Metadata

Metadata beeinflusst Use:

- Haltbarkeit sinkt
- Munition wird geladen
- Dokument wird angezeigt
- Schluessel prueft Ziel
- Container wird geoeffnet

### Destroy

Destroy entfernt eine Iteminstanz nach Benutzung, zum Beispiel Verbrauchsitems.

### Create

Create erzeugt neue Items, zum Beispiel leere Flasche nach Trinken oder Dokumentkopie.

### Replace

Replace tauscht Iteminstanzen, zum Beispiel rohes Item zu verarbeitetem Item.

### Events

Use Actions koennen interne Events ausloesen, aber nie ungeprueft aus Clientdaten.

### Server Events

Server Events sind autoritativ und duerfen Zustand veraendern.

Beispiele:

- Hunger erhoehen
- Armor setzen
- Health veraendern
- Item entfernen
- Cooldown speichern

### Client Events

Client Events sind Darstellung:

- Animation
- Sound
- Screen Effect
- Notification
- UI Preview

Client Events duerfen keinen Besitz veraendern.

## 11. Storage

Storage ist ein Inventory mit Zugriffskontext.

### Organisation

Organisationsstorage gehoert einer Organisation aus JobsCreator. Zugriff wird ueber Module, Grades und Permissions gesteuert.

Beispiele:

- Armory
- Evidence
- Medical Storage
- Business Storage
- Gang Stash

### Haus

Hausstorage gehoert Property-Systemen. Zugriff ueber Besitzer, Keys, Mitbewohner oder Admins.

### Fahrzeug

Fahrzeugstorage nutzt Fahrzeugidentitaet. Kofferraum und Handschuhfach koennen getrennte Inventare sein.

### Temporaer

Temporaerer Storage existiert nur fuer Sessions, Events oder Instanzen.

### Beweise

Evidence Storage braucht Audit, Zugriffshistorie und Case-Verknuepfung.

### Container

Container Storage gehoert zu Iteminstanzen und bewegt sich mit ihnen.

## 12. Drops

Drops sind Weltinventare.

### Boden

Ein Drop entsteht, wenn ein Item auf den Boden gelegt wird. Der Server erzeugt eine Drop-Inventory-Instance.

### Lebensdauer

Drops haben TTL:

- kurze TTL fuer normale Items
- laengere TTL fuer Missionen
- persistente Drops nur explizit

### Ownership

Drop Ownership kann offen oder eingeschraenkt sein:

- nur Ersteller fuer kurze Zeit
- Gruppe
- Organisation
- alle Spieler in Reichweite

### Instancing

Drops gehoeren zu Dimension, Interior, Routing Bucket oder Weltinstanz.

### Sync

Der Server synchronisiert nur relevante Drops:

- Distanzfilter
- Instanzfilter
- Visibility-Regeln
- Despawn bei leerem Drop

## 13. Crafting Integration

Crafting konsumiert Inventory Items und erzeugt neue Iteminstanzen.

### Materialien

Materialien kommen aus Inventory und werden serverseitig reserviert, bevor Crafting startet.

### Rezepte

Rezepte definieren:

- Inputs
- Outputs
- Dauer
- Werkbank
- Permission
- Job/Organisation
- Skill
- Failure-Regeln

### Werkbaenke

Werkbaenke koennen eigene Inventare haben und nur bestimmte Rezepte erlauben.

### JobsCreator

JobsCreator bestimmt, welche Organisationen Crafting-Module besitzen und welche Grades Rezepte nutzen duerfen.

## 14. Shop Integration

Shop Studio definiert Shops und Shop Items. Inventory fuehrt Besitz- und Stockbewegungen aus.

### Kaufen

Beim Kaufen:

1. Shop prueft Sortiment, Preis, Stock und Permission.
2. Economy prueft und bucht Zahlung.
3. Inventory erzeugt oder bewegt Iteminstanz ins Zielinventar.
4. Shop Stock wird reduziert, wenn limitiert.

### Verkaufen

Beim Verkaufen:

1. Shop prueft, ob Item sellable ist.
2. Inventory prueft Besitz und Menge.
3. Item wird entfernt oder in Shop-Stock ueberfuehrt.
4. Economy zahlt Gegenwert aus.

### Stock

Stock kann virtuell oder inventorybasiert sein.

- Virtuell: Shop hat unendlichen Bestand.
- Inventorybasiert: Shop besitzt ein echtes Inventory.

### Item Instanzen

Shops muessen Iteminstanzen respektieren:

- Waffen behalten Seriennummern.
- Dokumente behalten Inhalt.
- Kleidung behaelt Skin.
- Qualitaet kann Preis beeinflussen.

## 15. Roadmap

### Foundation

Bereits vorbereitet:

- Inventare
- Inventory Items
- Owner Types
- serverseitige Exports
- Nexa Callbacks
- Itemvalidierung gegen Item Studio
- idempotente Migration

### Item Instances

Naechste Schritte:

- Instanz-Metadata-Regeln
- Stack-Kompatibilitaet
- Seriennummern
- Haltbarkeit
- Audit Events

### Storage

Danach:

- Storage Registry
- Property Storage
- Vehicle Storage
- Organization Storage
- Evidence Storage

### Drops

Danach:

- Drop-Inventory-Instances
- Weltpositionen
- TTL
- Distanz-Sync
- Instancing

### Drag & Drop

Danach:

- Inventory UI
- Client-Intent Events
- serverseitige Move-Validierung
- Rollback bei Ablehnung

### Quick Slots

Danach:

- Quick Slot Mapping
- Use Shortcuts
- Validierung bei Itemverlust

### Crafting

Danach:

- Recipe Foundation
- Workbenches
- Materialreservierung
- JobsCreator-Modul

### Shops

Danach:

- Shop Stock als Inventory
- Buy/Sell-Transaktionen
- Iteminstanz-Verkauf

### Economy

Danach:

- Zahlungstransaktionen
- Steuern
- Organisationsumsatz
- Item Currency

### JobsCreator

Danach:

- Organisationstorage
- Armory
- Evidence
- Medical Storage
- Grade Permissions
- Module-basierte Freischaltung

## Architekturgrundsaetze

- Server ist Quelle der Wahrheit.
- Client sendet nur Absichten.
- Itemdefinitionen kommen aus Item Studio.
- Inventory Items sind konkrete Instanzen.
- Jede Mutation muss validiert werden.
- Weight, Slots und Stackregeln werden serverseitig berechnet.
- Container duerfen keine Zyklen erzeugen.
- Organisationen und Jobs werden generisch ueber JobsCreator angebunden.
- Shops und Crafting arbeiten ueber Inventory-Transaktionen.
- Kritische Bewegungen sind auditierbar.
