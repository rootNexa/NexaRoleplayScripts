# Police Admin Integration

Die Admin-Integration fuer Polizei-, Dispatch-, Medical-, Evidence- und License-Systeme bleibt eine Kontroll- und Audit-Schicht. Sie erzeugt keine festen Fraktionsrollen und fuehrt keine Gameplay-Aktionen ohne serverseitige Permission-Pruefung aus.

## Berechtigungsgrenzen

- `nexa.police.view` liest Police-Foundation-Daten.
- `nexa.police.manage` verwaltet Police-Agency-Grunddaten.
- `nexa.dispatch.manage` verwaltet Einsaetze und Einheitenstatus.
- `nexa.medical.manage` darf Medical-State administrativ korrigieren.
- `nexa.evidence.manage` darf Beweisstatus und Locker-Zuweisungen korrigieren.
- `nexa.licenses.manage` darf Lizenztypen und Lizenzstatus administrativ pflegen.

## Audit

Jede administrative Korrektur muss mit Source, Account/Character-Kontext, Zielobjekt, Grund und Correlation-ID protokolliert werden. Clientdaten sind nur Eingaben; Entscheidungen werden serverseitig gegen Permissions und Modulstatus geprueft.

## Grenzen

Admin-Integration ersetzt keine Organisation, keinen MDT-Typ und keine Agency-Zugehoerigkeit. Sie ist ein Recovery- und Moderationswerkzeug fuer Sonderfaelle.
