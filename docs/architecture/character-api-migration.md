# Character API Migration

Stand: 2026-07-10

Dieses Dokument beschreibt die Kompatibilitaetsmigration von Core-Character-APIs zur neuen Domain `nexa_characters`.

## Neue Ziel-API

Primaerer Owner:

```text
[nexa-gameplay]/nexa_characters
```

Neue Exports:

- `exports['nexa_characters']:ListCharacters(source)`
- `exports['nexa_characters']:GetCharacter(characterId)`
- `exports['nexa_characters']:GetActiveCharacter(source)`
- `exports['nexa_characters']:CreateCharacter(source, payload)`
- `exports['nexa_characters']:SelectCharacter(source, characterId)`
- `exports['nexa_characters']:UpdateCharacter(source, characterId, changes)`
- `exports['nexa_characters']:DeleteCharacter(source, characterId, reason)`
- `exports['nexa_characters']:BlockCharacter(source, characterId, reason)`
- `exports['nexa_characters']:RestoreCharacter(source, characterId)`

## Kompatibilitaet

`[nexa-core]/nexa-character` bleibt als Compatibility Resource erhalten und delegiert an `nexa_characters`.

Alte Core-Exports bleiben vorerst bestehen:

- `GetCharacter`
- `ListCharacters`
- `CreateCharacter`
- `SelectCharacter`
- `UpdateCharacter`

Diese Core-Exports loggen rate-limited Deprecation-Warnungen pro aufrufender Resource. Der Core bekommt keine Dependency auf `nexa_characters`.

## Migrationsregel

Neue Ressourcen duerfen Core-Character-Exports nicht mehr verwenden. Sie nutzen:

1. `nexa_characters` direkt fuer Character-Domain-Operationen.
2. `nexa_api`, falls eine stabile API-Fassade benoetigt wird.

## Entfernungspfad

1. Verbraucher auf `nexa_characters` oder `nexa_api` umstellen.
2. Runtime pruefen.
3. Deprecation-Warnungen auf Null bringen.
4. Core-Character-Fachlogik in einem spaeteren Kompatibilitaetsschnitt entfernen.
