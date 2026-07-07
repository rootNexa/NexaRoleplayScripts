# nexa_phone

Phase-5D-Resource fuer Phone UI und sichere Basisfunktionen.

## Umfang

- Phone-Grundstruktur mit NUI-App-Shell
- App-Liste und Navigation
- Kontakte als Basisdaten/Anzeige
- Nachrichten mit serverseitiger Validierung und Rate-Limits
- Anrufhistorie nur als Basisdaten/Anzeige, kein echtes Voice-System
- Notizen mit serverseitiger Validierung und Rate-Limits
- Mail-Grundstruktur als Anzeige
- deutsche, lore-friendly Texte
- Nutzung von `nexa_ui`
- minimale `ox_lib`-Interaktionen
- Audit/Logging fuer serverseitige Schreibaktionen

## Grenzen

- Phone ist in Phase 5D nur UI und sichere Basisfunktionen.
- Keine kritischen Entscheidungen im Client.
- Keine Geld-, Item-, Job-, Fraktions- oder Adminlogik.
- Keine direkten Datenbankzugriffe aus dem Client oder aus dieser UI-Resource.
- Kein echtes Voice-/Telefon-System.
- Kein Social-Media-Vollsystem.
- Keine Kamera, kein Galerie-Upload und kein Darknet.
- Keine MDT-, Polizei-/EMS-, Banking- oder Admin-UI.
- Keine neuen Gameplay-Systeme.
