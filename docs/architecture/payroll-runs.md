# Payroll Runs

Ein Run verarbeitet eine geschlossene Periode fuer eine Organisation.

Ablauf: Periodenabschluss, Organisation/Konto pruefen, Mitglieder und Duty-Zeit laden, Policies aufloesen, Entries erstellen, Deckung pruefen, Economy-Reservation/Transfers ausfuehren, Audit schreiben.

Default fuer fehlende Deckung: `all_or_nothing`.
