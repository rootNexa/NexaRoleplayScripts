# Identifier Policy

Stand: 2026-07-10

Identifier dienen der technischen Account-Aufloesung und Missbrauchserkennung.

## Gespeicherte Identifier

- `license`
- `license2`
- `fivem`
- `discord`
- `steam`

## Nicht als Account-Identifier gespeichert

- IP-Adresse
- Hardware-ID
- Tokens oder Secrets

## Tabelle `nexa_account_identifiers`

- `account_id`
- `identifier_type`
- `identifier_value`
- `identifier_hash`
- `first_seen_at`
- `last_seen_at`
- `verified`
- `active`

## Regeln

- `license` oder `license2` ist Pflicht fuer Account-Aufloesung.
- Fehlende optionale Identifier verhindern Login nicht automatisch.
- Identifier werden normalisiert und kleingeschrieben.
- Identifier duerfen nicht unmaskiert geloggt werden.
- IP-Adressen duerfen nicht allein ueber Accountgleichheit entscheiden.
- Hardware-ID-Logik ist nicht erlaubt.

## Logging

Logs verwenden maskierte Identifier, zum Beispiel:

```text
license:abcd...1234
```

Vollstaendige Identifier bleiben Datenbankdaten und duerfen nicht in normalen Logs oder Clientantworten erscheinen.
