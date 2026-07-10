# Jobs Migration Plan

## Reihenfolge

1. Neue `nexa_organizations`-Foundation.
2. Neue `nexa_jobs`-Foundation.
3. PlayerState-Integration fuer Job-Load.
4. Duty-Runtime-Tests.
5. Legacy-Job-APIs als deprecated markieren.
6. Feste Fraktionslogik durch Module und Organisationstypen ersetzen.

## Datenmigration

Bestehende Member- und Grade-Daten aus JobsCreator koennen spaeter ueber ein kontrolliertes Script uebernommen werden. Dabei werden mindestens fuenf Ranks, genau ein Owner-Rank, aktive Membership-Eindeutigkeit und Audit-Kontext erzwungen.

## Nicht in Kapitel 09

Keine Payroll, keine Duty-Kleidung, keine Fraktionsfahrzeuge, keine MDT-Fachmodule und keine NUI.
