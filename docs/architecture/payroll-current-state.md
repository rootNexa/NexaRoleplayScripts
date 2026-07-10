# Payroll Current State

Vor Kapitel 10 gibt es keine dedizierte `nexa_payroll`-Resource. Duty existiert in `nexa_jobs`, Organisationen und Ranks in `nexa_organizations`, Konten und Ledger in `nexa_economy`.

Legacy-Quellen wie `nexa_jobscreator`, `nexa_jobs_core`, `nexa_business` oder feste Faction-Ressourcen koennen Salary- oder Duty-Begriffe enthalten, sind aber nicht die Zielarchitektur.

Risiken:

- doppelte Auszahlung bei Restart
- unklare Geldquelle
- Auszahlung ohne Ledger
- Duty nur als Momentaufnahme statt Periodenzeit
- direkte Legacy-Balance-Mutationen

Kapitel 10 fuehrt eine neue Payroll-Domain ein und migriert keine Legacy-API blind.
