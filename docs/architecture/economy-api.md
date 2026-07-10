# Economy API

Die Economy stellt serverseitige Exports und Nexa-Callbacks bereit. Mutierende APIs akzeptieren strukturierte Payloads und liefern ein einheitliches Response-Format.

## Response

Erfolg:

```lua
{ success = true, code = "OK", message = "ok", data = ... }
```

Fehler:

```lua
{ success = false, code = "ERROR_CODE", message = "Safe public message", data = nil }
```

## Exports

- `GetAccount`
- `GetCharacterBankAccount`
- `GetBalance`
- `GetAvailableBalance`
- `GetReservedBalance`
- `GetLedger`
- `GetTransaction`
- `GetCash`
- `GetDirtyCash`
- `CanAfford`
- `Credit`
- `Debit`
- `Transfer`
- `Reserve`
- `CaptureReservation`
- `ReleaseReservation`
- `DepositCash`
- `WithdrawCash`
- `AddCash`
- `RemoveCash`
- `AddDirtyCash`
- `RemoveDirtyCash`

## Callbacks

Callbacks sind fuer kontrollierte UI- oder Gameplay-Abfragen gedacht, nicht fuer beliebige Clientmacht. Character und Source werden serverseitig bestimmt.
