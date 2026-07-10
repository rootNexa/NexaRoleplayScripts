# Identity and Character Operations

Stand: 2026-07-10

## Development-Startreihenfolge

```cfg
ensure nexa-core
ensure nexa_identity
ensure nexa_characters
ensure nexa-character
ensure nexa-identity
```

`nexa-character` ist nur noch Compatibility Wrapper. Neue Ressourcen sollen `nexa_characters` verwenden.

## Migrationen

`nexa_identity` registriert:

- `010_identity_accounts`

`nexa_characters` registriert:

- `020_characters_domain_columns`

Die Migrationen laufen ueber den Core-Migrationslayer. Sie sind append-only.

## Monitoring

Wichtige Events:

- `nexa:internal:identity:ready`
- `nexa:internal:identity:rejected`
- `nexa:internal:characters:selected`
- `nexa:internal:characters:released`

## Deprecation

Core-Character-Exports loggen rate-limited Warnungen. Diese Warnungen zeigen, welche Resources noch auf alte Core-Character-APIs zugreifen.
