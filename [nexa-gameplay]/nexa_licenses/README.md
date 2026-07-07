# nexa_licenses

Phase-4B-Resource fuer Lizenztypen, Lizenzausstellung, Entzug, Validierung und Historie.

## Abhaengigkeiten

- ox_lib
- nexa_api
- nexa_documents
- nexa_permissions
- nexa_security
- nexa_logs

## Datenbanktabellen

- licenses
- license_types
- license_history

## Server-Callbacks

- `nexa:licenses:cb:listTypes`
- `nexa:licenses:cb:issueLicense`
- `nexa:licenses:cb:revokeLicense`
- `nexa:licenses:cb:validateLicense`
- `nexa:licenses:cb:getHistory`

## Events

- `nexa:licenses:server:requestIssueLicense`
- `nexa:licenses:server:requestRevokeLicense`
- `nexa:licenses:server:requestValidateLicense`
- `nexa:licenses:client:openMenu`
- `nexa:licenses:client:requestResult`

## Permissions

- `licenses.issue`
- `licenses.revoke`

## API-Contracts

- `license.listTypes`
- `license.issue`
- `license.revoke`
- `license.validate`
- `license.history`

## Grenzen

Diese Resource implementiert keine Fahrschule, kein Waffen- oder Polizei-/EMS-Gameplay, keine Jobs und keine grosse UI. Kritische Schreibaktionen laufen ueber `nexa_api`.
