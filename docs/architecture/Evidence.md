# GP16 Evidence

`nexa_evidence` besitzt Evidence Types, World Traces, Evidence Records, Packaging, Chain of Custody, Locker Storage und Analysis.

## States

Evidence: `discovered -> collected -> packaged -> stored -> checked_out -> in_analysis -> analyzed -> stored|released|destroyed`, mit `missing` und `contaminated`.

## APIs

Exports: `RegisterEvidenceType`, `CollectEvidence`, `ListEvidence`, `UpdateEvidenceStatus`, `CreateTrace`, `PackageEvidence`, `RecordCustody`, `RequestAnalysis`, `CompleteAnalysis`, `StoreEvidenceLocker`.

Jede Custody-Aktion schreibt eine append-only Historie.
