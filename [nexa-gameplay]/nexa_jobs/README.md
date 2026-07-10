# nexa_jobs

`nexa_jobs` is the server-authoritative runtime layer for active jobs and duty.

## Boundaries

- Organization, rank and membership data belongs to `nexa_organizations`.
- Duty runtime and source-bound job state belongs here.
- Payroll, vehicles, dispatch, MDT and clothing are future modules.

## Rules

- The client cannot set job, rank or duty.
- Active character is resolved server-side from Source.
- Duty requires active membership and `organization.duty.use`.
- Duty ends on disconnect and resource stop.

## Exports

- `GetJob`
- `GetJobByCharacter`
- `IsOnDuty`
- `StartDuty`
- `StopDuty`
- `GetActiveDutyMembers`
- `ForceStopDuty`
