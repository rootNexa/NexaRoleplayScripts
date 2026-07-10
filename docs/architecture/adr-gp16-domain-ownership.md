# ADR GP16 Domain Ownership

## Entscheidung

GP16 nutzt getrennte fachliche Ressourcen statt einer monolithischen Emergency-Resource.

## Begruendung

Medical, EMS, Police, Dispatch, MDT, Evidence und Licenses besitzen unterschiedliche Persistenz-, Permission- und Audit-Grenzen. Klare Ownership verhindert doppelte Wahrheiten und macht GP17-Frontends stabil.

## Konsequenz

Cross-Domain-Zugriffe erfolgen ueber dokumentierte Exports und Nexa-Callbacks. UI-Clients greifen niemals direkt auf Datenbanken zu.
