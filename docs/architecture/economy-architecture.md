# Economy Architecture

`nexa_economy` ist die serverautoritative Money-Foundation fuer Nexa Roleplay. Die Resource verwaltet ausschliesslich nicht-physisches Kontogeld, Buchungen, Ledger, Reservierungen, Idempotenz und Audit. Physisches Bargeld bleibt Item- und Inventory-Domain.

## Ziele

- Bankgeld wird nie direkt als Character-, Job- oder Inventory-Feld gespeichert.
- Jede Balance-Aenderung erzeugt eine Transaktion, Ledger-Zeilen und Audit-Kontext.
- Alle externen Aufrufe laufen ueber klar benannte serverseitige Exports oder registrierte Nexa-Callbacks.
- Alle Betragswerte sind Integer in kleinster Einheit. Float-Rechnung ist verboten.
- Clientdaten sind nur Eingabewunsch, nie Wahrheit fuer Account, Character, Source oder Balance.

## Komponenten

- Currencies: registriert `bank`, `cash` und `dirty_cash`, trennt aber Buchgeld von Item-Waehrungen.
- Accounts: verwaltet Character-, Organisations-, Government-, System-, Escrow- und temporaere Konten.
- Transactions: fuehrt Credit, Debit, Transfer, Adjust und Reverse atomar aus.
- Ledger: bildet die unveraenderliche Buchungshistorie pro Konto ab.
- Reservations: sperrt verfuegbare Mittel fuer spaetere Capture- oder Release-Schritte.
- Idempotency: verhindert doppelte Ausfuehrung bei Retries.
- Sagas: koordiniert Mehr-Domain-Vorgaenge wie Deposit und Withdraw zwischen Inventory und Economy.
- Audit: dokumentiert administrative und sicherheitsrelevante Aktionen.

## Startverhalten

`nexa_economy` startet nach `nexa-core`, `nexa_api`, `nexa_items` und `nexa_inventory`. Beim Start werden Migrationen registriert, Currency-Items vorbereitet und der Status der Abhaengigkeiten geprueft. Fehlende optionale Domains deaktivieren nur betroffene Funktionen; fehlende Core- oder Datenbankfunktionen machen die Resource nicht bereit.

## Grenzen

Die Economy implementiert kein Inventory, keine UI, keine Shops, kein Paycheck-System und keine Gameplay-Jobs. Sie stellt nur die buchhalterische Grundlage bereit, auf der Shops, JobsCreator, Inventory, Banking und Adminsysteme aufbauen.
