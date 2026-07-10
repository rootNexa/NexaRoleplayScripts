# GP16 Police

`nexa_police` besitzt Police-Gameplay-Aktionen: Agency Registry, Arrest Records, Restraints, Escort, Search, Seizure, Fines, Booking, Incarceration und Transport.

## States

Booking: `draft -> finalized|cancelled`.

Incarceration: `scheduled -> active -> completed|released|escaped|admin_released`.

## APIs

Exports: `RegisterPoliceAgency`, `SetHandcuffed`, `SetEscorted`, `SearchPerson`, `SeizeItem`, `IssueFine`, `CreateBooking`, `FinalizeBooking`, `StartIncarceration`, `ReleaseIncarceration`, `StartTransport`, Checks fuer Person/Fahrzeug/Waffe.

Alle kritischen Aktionen sind serverseitig und fuer Audit/Permission-Hooks vorbereitet.
