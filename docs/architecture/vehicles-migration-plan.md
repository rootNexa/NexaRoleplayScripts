# Vehicles Migration Plan

1. Neue Fahrzeugfoundation parallel aufbauen.
2. Legacy-APIs einfrieren und nur noch lesen.
3. Definitionen, Ownership, Keys, Garages und Impound in neue Tabellen ueberfuehren.
4. Spawn/Despawn erst nach Runtime-Abnahme produktiv nutzen.
5. Legacy-Ressourcen entfernen, wenn Dependency-Graph und Runtime-Tests keine Nutzer mehr zeigen.

Keine automatische Migration in Großprompt 11.
