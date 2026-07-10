# Jobs Architecture

`nexa_jobs` ist die Runtime-Domain fuer den aktiven Job eines Spielers.

## Verantwortlichkeiten

- Active Character aus Source ableiten.
- Aktive Membership ueber `nexa_organizations` laden.
- Job-State pflegen.
- Duty-Session starten und beenden.
- Duty bei Disconnect und Resource-Stop bereinigen.
- interne Events fuer Job Ready und Duty senden.

Jobs speichert keine Organisationen, Ranks oder Memberships. Diese Daten bleiben in `nexa_organizations`.
