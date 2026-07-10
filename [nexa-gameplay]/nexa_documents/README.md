# nexa_documents

Phase-4B-Resource fuer Dokumenttypen, Dokumentausstellung, Widerruf und Validierung.

## Abhaengigkeiten

- nexa_ui
- nexa_api
- nexa_identity
- nexa_security
- nexa_logs

## Datenbanktabellen

- documents
- document_types
- document_signatures

## Server-Callbacks

- `nexa:documents:cb:listTypes`
- `nexa:documents:cb:issueDocument`
- `nexa:documents:cb:revokeDocument`
- `nexa:documents:cb:validateDocument`

## Events

- `nexa:documents:server:requestIssueDocument`
- `nexa:documents:server:requestRevokeDocument`
- `nexa:documents:server:requestValidateDocument`
- `nexa:documents:client:openMenu`
- `nexa:documents:client:requestResult`

## Permissions

- `documents.issue`
- `documents.revoke`

## API-Contracts

- `document.listTypes`
- `document.issue`
- `document.revoke`
- `document.validate`

## Grenzen

Diese Resource implementiert keine grosse UI, kein Banking, keine Jobs, keine Behoerden-Gameplay-Systeme und keine eigene Datenbankwahrheit. Kritische Schreibaktionen laufen ueber `nexa_api`.
