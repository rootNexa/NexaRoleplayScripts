# Admin Duty

## Purpose

Admin Duty is a server-side state used to separate regular play from operational admin actions.

## States

- `off_duty`
- `on_duty`
- `suspended`

## Rules

- Duty state is stored server-side.
- Disconnect clears in-memory duty.
- Resource stop clears in-memory duty.
- Duty actions are audited.
- Normal players do not receive sensitive duty data.
- Owner and security recovery permissions must not depend fully on duty.

## Duty-Gated Permissions

Operational actions may require duty:

- `nexa.admin.teleport`
- `nexa.admin.noclip`
- `nexa.admin.spectate`
- `nexa.admin.freeze`
- `nexa.admin.revive`
- `nexa.admin.heal`
- `nexa.admin.kick`
- `nexa.admin.warn`
- `nexa.admin.inventory.view`
- `nexa.admin.money.view`
- `nexa.admin.vehicle.view`
- `nexa.support.teleport`
- `nexa.support.freeze`
- `nexa.support.revive`

## API

- `SetAdminDuty(source, state, actor, reason)`
- `GetAdminDuty(source)`
- `IsAdminOnDuty(source)`
- `ClearAdminDuty(source, reason)`
