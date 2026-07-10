# Payroll Migration Plan

1. `nexa_payroll` parallel einfuehren.
2. Salary-/Paycheck-Logik in Legacy-Ressourcen einfrieren.
3. Payroll-Policies pro Organisation und Rank erstellen.
4. Duty-Zeit aus `nexa_job_duty_sessions` auswerten.
5. Auszahlungen ueber `nexa_economy` aus Organisationskonten buchen.
6. Runtime-Tests mit isolierten Testorganisationen ausfuehren.
7. Legacy-Salary-APIs erst entfernen, wenn keine Nutzer mehr existieren.

Entfernungskriterien: keine Legacy-Paycheck-Calls, keine direkte Geldschoepfung, alle Payroll-Validatoren gruen.
