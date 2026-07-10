# GP17 Architecture

GP17 baut die Kommunikations- und Frontend-Ebene auf GP01-GP16. Die UI konsumiert offizielle Nexa-Services und erzeugt keine parallele Fachlogik.

## Ressourcen

- `nexa_theme`: Theme Tokens.
- `nexa_ui_components`: gemeinsame Komponenten-Contracts und CSS.
- `nexa_phone`: Telefon-Domain und Phone-NUI.
- `nexa_radio`: Funkfrequenzen, Kanaele, Memberships und Prioritaeten.
- `nexa_documents`: digitale Dokumente, Versionen, Signaturen und Freigaben.
- `nexa_banking_ui`: Banking-Frontend auf `nexa_banking`.
- `nexa_mdt_ui`: MDT-Frontend auf `nexa_mdt`.
- `nexa_dispatch_ui`: Dispatch-Frontend auf `nexa_dispatch`.

## Regeln

Frontends nutzen NUI nur fuer Anzeige und Eingabe. Mutationen laufen ueber `nexa_api` Callbacks oder bestehende serverseitige Exports.
