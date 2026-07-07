# nexa_qbox_compat

Compatibility resource for the ADR-005 decision: Qbox is framework-only, Nexa is persistence-authoritative.

## Redirected Or Disabled Qbox DB Features

- `qbx_core` ban check is redirected to `nexa_qbox_compat:checkBanForSource`, which reads Nexa `players`, `player_identifiers` and `bans.expires_at`.
- `qbx_core` multicharacter is disabled with `characters.useExternalCharacters = true`; Nexa Identity owns character creation, selection and spawn.
- The client bridge closes loading screens after network start and opens the Nexa Identity manager instead of Qbox character UI.
- Empty accounts, existing Nexa characters, character creation, character selection and spawn all remain on `nexa_identity`/`nexa_api`; the bridge does not call Qbox multicharacter callbacks.
- Runtime spawn/fade/focus cleanup is handled by `nexa_identity:client:spawnPrepared`, which uses `spawnmanager`, closes loading screens, clears NUI focus and cameras, unfreezes and shows the player, then emits Qbox loaded events for framework consumers.
- Set `nexa:identityDebug` to `true` for temporary client-side flow logs; it defaults to off.
- `qbx_core` character cleanup tables are disabled in Qbox config so optional NPWD, skin, outfit, vehicle and group tables are not required.
- `qbx_core` startup mutation of Nexa `players` is disabled while `nexa:qboxCompat` is true.
- `qbx_management` is not started by default. If accidentally started, `player_jobs_activity` exists as a compatibility sidecar without a Qbox FK to `players.citizenid`.
- `ox_inventory` receives `player_vehicles` as a compatibility view over Nexa `vehicles` and `vehicle_garage_states`.
- If a legacy `player_vehicles` table already exists, it is never dropped. It is renamed to `player_vehicles_legacy_qbox` or a timestamped variant before the Nexa-backed view is installed.
- If preserving the legacy table fails because of permissions or a concurrent startup, the resource logs a warning and keeps the existing table instead of throwing or deleting data.
- Existing `player_vehicles` views are replaced with `CREATE OR REPLACE VIEW`, making repeated starts idempotent.
- `playerskins` and `player_outfits` are empty read-only views.
- `player_groups` is a read-only view over Nexa jobs and factions.

## Authoritative Nexa Tables

- Bans: `bans.expires_at`, `players.is_banned`, `player_identifiers`
- Vehicles: `vehicles`, `vehicle_garage_states`
- Jobs: `jobs`, `job_grades`, `character_jobs`
- Factions: `factions`, `faction_grades`, `faction_members`

The sidecar table `nexa_qbox_vehicle_inventory` stores only Ox glovebox/trunk payloads keyed by Nexa vehicle id. It is not a vehicle ownership model.

## Replacement Boundary

This resource contains only server-side compatibility adapters. It registers no gameplay events, commands, client scripts, jobs, items, factions, shops or progression rules.

It can be removed later by stopping `nexa_qbox_compat`, dropping the compatibility views/sidecars (`player_vehicles`, `playerskins`, `player_outfits`, `player_groups`, `player_jobs_activity`, `nexa_qbox_vehicle_inventory`) and pointing Ox/Qbox integrations at native Nexa APIs. Preserved legacy tables named `player_vehicles_legacy_qbox*` can be archived or inspected separately. No Nexa canonical table requires a schema change for that removal.
