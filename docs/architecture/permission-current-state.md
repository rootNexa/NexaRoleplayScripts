# Permission Current State

## Scope

This document captures the permission state before the Chapter 03 migration. It covers the legacy `nexa_permissions` resource, the technical permission engine in `nexa-core`, existing callers, ACE usage, database ownership, and open migration risks.

## Existing Systems

| Location | Current Purpose | Current Owner | Data Source | Security Risk | Future Owner | Migration Strategy | Compatibility Need | Removal Criteria |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `[nexa-core]/nexa-core/server/permissions.lua` | Technical permission decision engine, role inheritance, subject roles, subject permissions, ACE fallback, decision trace | `nexa-core` | Core DB layer and migration `002_permission_foundation` | Medium: currently has technical defaults but no full admin domain catalog or owner protection | `nexa-core` for decision engine only | Keep as base engine and extend only where domain resource needs stable technical hooks | `exports['nexa-core']:HasPermission` must keep returning boolean | Kept permanently as low-level engine |
| `[nexa-core]/nexa_permissions` | Legacy/domain permission resource with roles, role rules, player assignments, cache, development commands | `nexa_permissions` | Direct `MySQL.*`, legacy SQL file, `nexa-core` player exports | High: direct oxmysql outside core DB layer, own model duplicates core tables, ACE evaluated before DB role rules | `nexa_permissions` domain resource | Refactor to use `nexa-core` DB layer and Core permission engine tables; keep legacy exports as wrappers | Existing exports `Has`, `GetRoles`, `AssignRoleToPlayer`, `ReloadPermissions` must continue | No direct `MySQL.*`, no `@oxmysql`, no duplicate source of truth |
| `[nexa-core]/nexa_api/server/exports.lua` | Public API wrapper for permission checks | `nexa_api` | `nexa-core:HasPermission` | Low: safe server-side wrapper | `nexa_api` | Keep caller contract | `nexa_api:HasPermission` should remain preferred for gameplay resources | Kept |
| `[nexa-world]/nexa_blips`, `nexa_zones`, `nexa_interiors`, `nexa_npcs` | Server-side permission gates for admin/world management | Resource owners | `nexa_api:HasPermission` | Low: checks are server-side and permission-based | Resource owners | No migration required in Chapter 03 | Permission names should be registered in catalog if used | Kept |
| `[nexa-gameplay]/nexa_characters` | Character administration gate | `nexa_characters` | `nexa-core:HasPermission` | Low: server-side boolean check | `nexa_characters` | Keep, later may route through `nexa_api` for consistency | `nexa.characters.*` names must be cataloged | Kept |
| `server` cfg/docs ACE examples | Bootstrap/fallback examples | Ops | FXServer ACE | Medium if treated as sole source of truth | Ops plus `nexa_permissions` bootstrap | ACE remains bootstrap/fallback only; DB Deny must win in effective decisions | Existing txAdmin/server.cfg not changed in this chapter | Kept as documented fallback only |

## Core Permission Foundation

`nexa-core` already provides:

- Account and character subject types through `subject_type`.
- Role table `nexa_permission_roles`.
- Role permission table `nexa_permission_role_permissions`.
- Role inheritance table `nexa_permission_role_inheritance`.
- Subject role table `nexa_permission_subject_roles`.
- Subject permission table `nexa_permission_subject_permissions`.
- Legacy `nexa_permissions` table fallback for old player permissions.
- Deny-before-allow evaluation.
- Wildcard candidates with `nexa.*` as the broadest technical fallback.
- ACE fallback after database rules.
- Decision traces.
- Cache and invalidation.

Missing before Chapter 03:

- Registered permission catalog.
- Domain role seed model for Owner/Admin/Support.
- Owner protection.
- Last-owner protection.
- Actor-aware mutating operations.
- Required audit reason for mutations.
- Dedicated permission audit table.
- Admin-duty state.
- `nexa_permissions` migration away from direct oxmysql.

## Legacy `nexa_permissions`

Current legacy traits:

- Depends on `oxmysql`, `nexa-lib`, and `nexa-core`.
- Loads `@oxmysql/lib/MySQL.lua`.
- Uses `MySQL.query.await`, `MySQL.insert.await`, and `MySQL.update.await` directly.
- Maintains `rolesByName`, `rolesById`, `rulesByRoleId`, `cacheBySource`, and `cacheByIdentifier`.
- Uses its own SQL file `sql/001_permissions_roles.sql`.
- Evaluates ACE before role rules in `evaluate`.
- Supports assignment by source or identifier, which must be narrowed to account/character subjects in the new model.
- Exposes legacy names that existing scripts may still call.

## Existing Callers

Known server-side callers:

- `exports.nexa_api:HasPermission(source, permission)` in world resources.
- `exports['nexa-core']:HasPermission(source, permission)` in `nexa_characters`.
- Development commands in `nexa_api` and `nexa_permissions`.

No current resource should make permission decisions on the client.

## ACE Usage

ACE appears in:

- Core decision engine as fallback.
- Legacy `nexa_permissions` direct fallback.
- Runtime validation docs and examples.

Target behavior:

- ACE can bootstrap or provide fallback.
- Database Deny must override ACE Allow.
- ACE must not overwrite database roles.
- ACE source checks must be cached and invalidable through normal permission cache invalidation.

## Risks

| Risk | Severity | Notes |
| --- | --- | --- |
| Duplicate permission tables and caches | High | Old `nexa_permissions` can disagree with `nexa-core`. |
| Direct oxmysql in `nexa_permissions` | High | Violates current architecture rule. |
| Owner role not protected | High | Mutating role operations can remove or grant critical power without hierarchy checks. |
| Missing audit table for permission mutations | High | Existing audit calls are not specific enough for admin accountability. |
| Legacy identifier assignments | Medium | Source/identifier assignment does not cleanly separate account and character scopes. |
| ACE precedence in legacy code | Medium | Legacy evaluation can allow before DB Deny. |
| Development commands too permissive in dev mode | Medium | Acceptable locally, must be documented and not relied on in production. |

## Current Decision

`nexa_core` remains the technical engine. `nexa_permissions` becomes the domain owner for catalog, role seed, account/character assignment, owner protection, audit, admin-duty, and compatibility exports.
