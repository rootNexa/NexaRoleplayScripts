# nexa_business

Business Core fuer Phase 4D.

## Umfang

- Business-Erstellung ueber `businesses`
- Business-Mitglieder ueber `business_members`
- Business-Konten ueber `accounts` mit `owner_type = 'business'` und `business_accounts`
- Business-Transaktionen ueber `business_transactions`
- Geldbewegungen nur ueber `nexa_api.account`
- minimale ox_lib-Interaktion per `/nexabusiness`

## Grenzen

- Keine grosse UI
- Keine Fahrzeug-, Housing-, Dispatch-, Polizei-, EMS- oder illegalen Systeme
- Keine `business_roles` oder `business_licenses`, weil diese Tabellen laut ADR-003 offen sind
