# GP16 Dispatch

`nexa_dispatch` besitzt Call Types, Calls, Units, Assignments, Status, Panic und History.

## States

Call: `open -> acknowledged -> assigned -> responding -> on_scene -> resolved`, mit `cancelled` und `expired` als Nebenpfade.

Unit: `available`, `busy`, `responding`, `on_scene`, `offline`, `panic`.

## APIs

Exports: `RegisterCallType`, `CreateDispatchCall`, `ListDispatchCalls`, `AssignDispatchUnit`, `UpdateDispatchStatus`, `SetUnitStatus`, `CreatePanic`, `RegisterDispatchAdapter`.

Calls koennen eine `dedupe_key` besitzen, damit automatische Quellen denselben Alarm nicht spammen.
