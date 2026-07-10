# Job Lifecycle

Zustaende:

- `unassigned`
- `assigned`
- `off_duty`
- `on_duty`
- `suspended`
- `unloading`

Ablauf: PlayerState active, Character aufloesen, aktive Membership laden, Organisation und Rank pruefen, Job-State setzen, standardmaessig off duty. Disconnect und Resource-Stop unloaden den Job und beenden offene Duty-Sessions.
