# nexa_evidence

Phase 9F stellt die serverseitige Evidence-Grundlage bereit:

- DNA
- Fingerabdruecke
- Huelsen
- Blut
- generische Beweismittel
- Beweiskette ueber Metadaten und Audit
- Police API als zentrale Schreibschicht

Grenzen:

- Kein Polizei-Gameplay.
- Keine Ermittlungs-UI.
- Keine Cliententscheidung ueber Typ, Status, Storage oder Audit.
- Keine direkten DB-Zugriffe in dieser Fachresource.

Persistenz und Audit laufen ueber `nexa_api.police` und `nexa_audit`. Evidence-Stashes werden der jeweiligen Evidence-Nummer zugeordnet.
