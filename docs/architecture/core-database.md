# Core Database

Stand: 2026-07-10

`nexa-core` besitzt eine kontrollierte Datenbank-Abstraktionsschicht ueber `oxmysql`. Sie ist bewusst kein ORM und kein grosser Query Builder. Fachmodule sollen spaeter Repository- oder Storage-Funktionen auf dieser Schicht aufbauen, statt SQL unkontrolliert im gesamten Framework zu verteilen.

## Ziele

- parametrisierte Queries
- einheitliche Fehlerobjekte
- Query-Kategorien
- Timeouts
- optionales langsames Query-Logging
- kontrollierte Retries fuer geeignete Fehler
- Health-Status
- Migrationen mit ID, Beschreibung, Status und Checksumme
- Kompatibilitaet zu bestehenden Core-Funktionen

## API

```lua
Nexa.Database.Query(sql, params, options)
Nexa.Database.Single(sql, params, options)
Nexa.Database.Scalar(sql, params, options)
Nexa.Database.Insert(sql, params, options)
Nexa.Database.Update(sql, params, options)
Nexa.Database.Delete(sql, params, options)
Nexa.Database.Transaction(queries, options)
Nexa.Database.IsReady()
Nexa.Database.GetHealth()
```

Kompatibilitaet:

```lua
Nexa.Database.FetchOne(sql, params, options)
Nexa.Database.FetchAll(sql, params, options)
Nexa.Database.Execute(sql, params, options)
Nexa.Database.CheckReady()
```

## Nutzung

```lua
local row, err = Nexa.Database.Single([[
    SELECT id, display_name
    FROM nexa_players
    WHERE identifier = ?
    LIMIT 1
]], { identifier }, {
    category = 'players.lookup'
})

if err then
    return nil, 'DATABASE_ERROR'
end
```

## Optionen

```lua
{
    category = 'characters.create',
    timeoutMs = 10000,
    slowQueryMs = 500,
    retries = 2,
    retryDelayMs = 100
}
```

`category` ist fuer Logging, Health und Diagnose gedacht. Kategorien sollen stabil und fachlich sein.

## Sicherheitsregeln

- Benutzerwerte werden immer ueber `params` gebunden.
- Keine String-Verkettung mit Client- oder Benutzereingaben.
- Dynamische Tabellen- oder Spaltennamen sind nur mit Whitelist erlaubt.
- Fehlerobjekte enthalten keine SQL-Strings.
- Rohfehler aus MariaDB werden nicht an Clients gegeben.
- Secrets duerfen nicht in SQL, Params oder Logs auftauchen.
- Transaktionen muessen vollstaendig committen oder rollbacken.

Dynamische Identifier duerfen nur so verwendet werden:

```lua
Nexa.Database.Query(sql, params, {
    identifier = columnName,
    identifierWhitelist = { 'display_name', 'last_seen_at' }
})
```

Diese Option validiert nur die Sicherheit des Identifier-Werts. Sie ersetzt nicht selbst den SQL-String.

## Fehlerstruktur

Fehler haben ein einheitliches Format:

```lua
{
    code = 'DB_QUERY_FAILED',
    message = 'Datenbankabfrage fehlgeschlagen.',
    category = 'database.query',
    retryable = false,
    details = nil
}
```

Stabile Codes:

- `DB_INVALID_INPUT`
- `DB_TIMEOUT`
- `DB_UNAVAILABLE`
- `DB_QUERY_FAILED`
- `DB_TRANSACTION_FAILED`
- `DB_MIGRATION_FAILED`
- `DB_MIGRATION_CHECKSUM_MISMATCH`

## Timeouts

`timeoutMs` begrenzt die Wartezeit auf eine Query oder Transaktion. Wenn die asynchrone oxmysql-API verfuegbar ist, wird ein Promise mit `SetTimeout` verwendet. Falls nur Await verfuegbar ist, wird die Dauer nach der Rueckkehr geprueft und als Timeout klassifiziert, wenn sie zu lang war.

## Slow Query Logging

`slowQueryMs` steuert langsames Query-Logging. Der Wert `0` deaktiviert diese Meldung. Langsame Queries werden als strukturierte Warnung mit Kategorie `database.slow_query` geloggt.

## Retries

Retries sind kontrolliert und nur fuer typische transiente Fehler vorgesehen:

- Deadlocks
- Lock wait timeouts
- verlorene Verbindung
- Server gone away
- Connection refused

Nicht retryable:

- Syntaxfehler
- Constraint-Fehler
- ungueltige Parameter
- Timeouts
- Migration-Checksum-Konflikte

## Transaktionen

```lua
local ok, err = Nexa.Database.Transaction({
    {
        query = 'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        params = { amount, fromAccount }
    },
    {
        query = 'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        params = { amount, toAccount }
    }
}, {
    category = 'banking.transfer'
})
```

Wenn `oxmysql` die Transaktion ablehnt, wird `false, err` geliefert. Fachmodule duerfen bei Fehlern keine Teilannahmen treffen.

## Migrationen

Migrationen werden intern registriert:

```lua
Nexa.Database.RegisterMigration({
    id = '001_foundation',
    description = 'Create core foundation tables',
    transaction = false,
    statements = {
        'CREATE TABLE IF NOT EXISTS ...'
    }
})
```

Die Migrationstabelle:

```sql
nexa_core_migrations
```

Felder:

- `id`
- `description`
- `checksum`
- `status`
- `executed_at`
- `error_message`

Schutzregeln:

- Migrations-IDs sind eindeutig.
- Angewendete Migrationen werden nicht erneut ausgefuehrt.
- Wenn eine angewendete Migration eine andere Checksumme hat, stoppt der Bootstrap.
- Fehlgeschlagene Migrationen werden mit Status `failed` markiert.
- DDL-Migrationen laufen ohne erzwungene Transaktion, weil MariaDB viele DDL-Statements implizit committet.
- DML-Migrationen koennen mit `transaction = true` transaktional laufen.

## Health

```lua
local health = Nexa.Database.GetHealth()
```

Health enthaelt:

- `ready`
- `lastCheckAt`
- `lastSuccessAt`
- `lastError`
- `totalQueries`
- `failedQueries`
- `slowQueries`
- `retriedQueries`
- `migrations.applied`
- `migrations.failed`

## Bootstrap

`nexa-core` prueft im Bootstrap:

1. Konfiguration
2. Pflichtabhaengigkeiten
3. Datenbankbereitschaft
4. Migrationen

Wenn Migrationen fehlschlagen oder eine Checksumme nicht passt, geht der Lifecycle auf `failed`.
