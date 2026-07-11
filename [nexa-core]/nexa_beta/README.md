# nexa_beta

`nexa_beta` ist die GP18-Integrations- und Abnahme-Resource. Sie erzeugt keine Gameplay-Domain, sondern buendelt:

- Creator Registry
- UI Preferences Schema
- Admin Settings Schema
- Feature Flags Schema
- Performance Baselines
- Release Metadata
- Health und Beta-Readiness

## Exports

- `RegisterCreator(payload)`
- `ListCreators()`
- `SetFeatureFlag(flagKey, enabled, value)`
- `CollectHealth()`
- `GetReadiness()`
- `RecordPerformanceSnapshot(payload)`
- `GetReleaseMetadata()`
- `getSchema()`

## Migration

`180_beta_readiness` erstellt alle GP18-Integrations- und Abnahme-Tabellen.
