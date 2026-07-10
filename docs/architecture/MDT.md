# GP16 MDT

`nexa_mdt` bleibt generisch nach `mdtType` und besitzt jetzt zusaetzlich eigene Domains fuer Cases, Reports, Warrants, BOLOs, Notes und Links.

## APIs

Exports: `CreateCase`, `CreateReport`, `FinalizeReport`, `CreateWarrant`, `CreateBolo`, `AddNote`.

Bestehende Snapshot- und Personensuche-Callbacks bleiben fuer GP17-Frontends erhalten.

## Grenzen

MDT stellt Fachinformationen dar und besitzt MDT-eigene Records. Es wird nicht Eigentuemmer von Medical State, Dispatch Calls, Evidence Objects, Licenses oder Vehicle Truth.
