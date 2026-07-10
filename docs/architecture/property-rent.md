# Property Rent

Rent is processed server-side using the lease amount and interval. Payments go through `nexa_economy`; there is no hidden money creation and no direct balance mutation.

Failed payments move leases toward `overdue` or `suspended` based on policy. Eviction is explicit and audited.
