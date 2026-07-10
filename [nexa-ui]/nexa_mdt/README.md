# nexa_mdt

Generisches MDT-Fundament fuer Organisationen, Jobs, Gangs, Fraktionen und Betriebe.

## Umfang

- MDT-Grundstruktur mit NUI-App-Shell
- generische `mdtType`-Struktur fuer `police`, `ems`, `government`, `gang`, `business` und `media`
- dynamische Modullisten je `mdtType`
- Personenabfrage mit serverseitiger Permission-Pruefung
- Fahrzeugabfrage als vorbereitete read-only Struktur ohne Fahrzeuglogik
- Aktenuebersicht
- Haftbefehle als vorbereitete Anzeige
- Bussgelder als vorbereitete Anzeige
- Einsatzberichte als vorbereitete Anzeige
- Beweisuebersicht als vorbereitete read-only Struktur ohne Evidence-Gameplay
- Dispatch-Anzeige ueber bestehende Dispatch-API
- Rate-Limits fuer Snapshot und Personenabfrage
- Audit/Logging bei Aktenzugriffen
- deutsche, lore-friendly Texte
- Nutzung von `nexa_ui`
- Nutzung des Nexa Callback-Systems ueber `nexa_api`

## Grenzen

- MDT ist Anzeige- und Workflow-System.
- Feste Fraktionsressourcen sind keine harte Abhaengigkeit.
- Bestehende Polizeiansichten laufen als `police`-Module weiter.
- Dispatch-Daten werden nur ueber `nexa_api['dispatch.listCalls']` angezeigt.
- `nexa_dispatch` hat keine harte Abhaengigkeit zu `nexa_mdt`.
- Keine kritischen Entscheidungen im Client.
- Keine direkten Datenbankzugriffe aus dem Client oder aus dieser UI-Resource.
- Kein Polizei- oder EMS-Gameplay.
- Keine Fahrzeug-Systeme.
- Kein Evidence-System als Gameplay.
- Kein Strafvollzug/Jail-System.
- Keine Bodycam/Dashcam.
- Keine Handy- oder Admin-UI.
- Keine neuen Gameplay-Systeme.
