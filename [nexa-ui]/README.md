# [nexa-ui]

Resource-Gruppe fuer zentrale und fachliche UI-Systeme.

## Phase 5A

Umgesetzt ist ausschliesslich:

- `nexa_ui` als zentrales NEXA Design-System
- NUI-Grundstruktur
- Notifications
- Confirm-Dialoge
- einfache Menues
- deutsche, lore-friendly UI-Texte

Weiterhin ausgeschlossen:

- HUD
- Handy
- Tablet
- MDT
- Banking-UI
- Polizei-/EMS-UI
- Fahrzeug-, Housing- und Gameplay-Systeme

## Phase 5B

Umgesetzt ist zusaetzlich:

- `nexa_hud` als reine Anzeige-Resource
- Statusanzeige
- Job-/Business-Anzeige
- Geldanzeige nur lesend
- Voice-/Funk-Anzeige ohne eigenes Funksystem
- Fahrzeuganzeige ohne Fahrzeuglogik
- HUD-Sichtbarkeit

Weiterhin ausgeschlossen:

- Handy
- Tablet
- MDT
- Banking-UI
- Fahrzeug-Systeme
- Funk-System
- Polizei-/EMS-UI
- Admin-UI
- neue Gameplay-Systeme

## Phase 5C

Umgesetzt ist zusaetzlich:

- `nexa_tablet` als reine Tablet UI-Shell
- App-Shell und Navigation
- deaktivierte, dokumentierte Platzhalter fuer Dienst-, Firmen- und Gruppen-Apps
- serverseitige Zugriffskontrolle ueber bestehende Permissions
- deutsche, lore-friendly Tablet-Texte
- minimale ox_lib-Interaktionen

Weiterhin ausgeschlossen:

- Handy
- MDT
- Banking-UI
- Polizei-/EMS-Systeme
- Fahrzeug-Systeme
- Housing
- Admin-UI
- neue Gameplay-Systeme

## Phase 5D

Umgesetzt ist zusaetzlich:

- `nexa_phone` als Phone UI-Shell
- App-Shell und App-Liste
- Kontakte als Basisdaten/Anzeige
- Nachrichten mit serverseitiger Validierung und Rate-Limits
- Anrufhistorie nur als Basisdaten/Anzeige ohne echtes Voice-System
- Notizen mit serverseitiger Validierung und Rate-Limits
- Mail-Grundstruktur
- deutsche, lore-friendly Texte
- minimale ox_lib-Interaktionen

Weiterhin ausgeschlossen:

- echtes Voice-/Telefon-System
- Social Media Vollsystem
- Kamera
- Galerie-Upload
- Darknet
- MDT
- Polizei-/EMS-Systeme
- Banking-UI
- Admin-UI
- neue Gameplay-Systeme

## Phase 5E

Umgesetzt ist zusaetzlich:

- `nexa_mdt` als Anzeige- und Workflow-System
- MDT-Grundstruktur mit App-Shell und Navigation
- Personenabfrage
- Fahrzeugabfrage als vorbereitete read-only Struktur
- Aktenuebersicht, Haftbefehle, Bussgelder und Einsatzberichte
- Beweisuebersicht als vorbereitete read-only Struktur
- Dispatch-Anzeige ueber bestehende Dispatch-API
- serverseitige Permission-Pruefung
- Rate-Limits
- Audit/Logging bei Aktenzugriffen
- deutsche, lore-friendly Texte

Weiterhin ausgeschlossen:

- Polizei-Gameplay
- EMS-Gameplay
- Fahrzeug-Systeme
- Evidence-System als Gameplay
- Strafvollzug/Jail-System
- Bodycam/Dashcam
- Handy
- Admin-UI
- neue Gameplay-Systeme
