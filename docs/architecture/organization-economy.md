# Organization Economy

Organisationen koennen ein Konto in `nexa_economy` besitzen. `nexa_organizations` speichert nur die Referenz `economy_account_id`.

Regeln:

- Konto wird serverseitig erstellt.
- Keine freie Konto-ID aus Clientdaten.
- Buchungen laufen nur ueber `nexa_economy`.
- Zugriff wird ueber Organisationspermissions wie `organization.account.view`, `organization.account.credit` und `organization.account.debit` geprueft.
