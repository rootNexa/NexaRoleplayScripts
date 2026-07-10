# Economy Accounts

Accounts sind die einzigen Speicherorte fuer Buchgeld. Ein Account gehoert einer Domain, hat einen Typ und kann aktiviert oder gesperrt werden.

## Account-Typen

- `character_bank`: Standard-Bankkonto eines Characters.
- `organization`: Konto einer Organisation aus JobsCreator.
- `government`: staatliche Konten fuer Steuern, Gebuehren und Verwaltung.
- `system`: technische Konten fuer Serverprozesse.
- `escrow`: Zwischenkonto fuer abgesicherte Ablaeufe.
- `temporary`: kurzlebige Konten fuer kontrollierte Workflows.

## Identitaet

Ein Account wird ueber `account_id` referenziert. Zusaetzlich besitzt er `owner_type` und `owner_id`. Clients duerfen diese Werte nie als vertrauenswuerdige Quelle setzen. Character-Konten werden aus serverseitigem Player-State bzw. Character-State abgeleitet.

## Lifecycle

Beim aktiven Gameplay-State eines Characters wird das Character-Bankkonto idempotent erstellt. Deaktivierte Konten bleiben lesbar, duerfen aber keine neuen Buchungen erhalten.

## Balance-Felder

- `balance`
- `reserved_balance`
- `currency`
- `status`
- `metadata_json`

Balance-Aenderungen sind nur ueber die Transaction-Engine erlaubt.
