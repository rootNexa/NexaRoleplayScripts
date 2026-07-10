# Identity and Character Privacy

Stand: 2026-07-10

## Gespeicherte Daten

Identity speichert:

- primaere License
- weitere normalisierte Identifier
- Accountstatus
- Login-/Logout-Zeitpunkte
- Review-Signale

Character speichert:

- Vorname
- Nachname
- Geburtsdatum
- Geschlecht
- Groesse
- Gewicht
- optionale Profilfelder

## Nicht gespeichert als Identifier

- Hardware-ID
- IP als permanenter Account-Identifier
- Tokens oder Secrets

## IP-Adressen

IP-Adressen duerfen hoechstens temporär und datenschutzbewusst fuer Runtime-Kontext oder schwache Risikoindikatoren genutzt werden. Sie entscheiden nie allein ueber Accountgleichheit oder Sperren.

## Logs

Identifier werden maskiert. Vollstaendige Identifier duerfen nicht in normalen Logs oder Clientantworten erscheinen.

## Aufbewahrung

Soft-Delete bleibt Standard fuer Charaktere. Physisches Loeschen wird erst entschieden, wenn Audit-, Referenz- und Datenschutzanforderungen gemeinsam bewertet wurden.
