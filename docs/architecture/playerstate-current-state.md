# Player State Current State

## Existing Resources

| Resource | Current Role | Risk | Future Owner |
| --- | --- | --- | --- |
| `[nexa-gameplay]/nexa-spawn` | Minimal development spawn at a fixed fallback point | No account/character binding, no token, no last-position persistence, no lifecycle state | Replaced by `nexa_playerstate` for production lifecycle |
| `[cfx]/[managers]/spawnmanager` | CFX standalone spawn helper | Not Nexa-authoritative, client-oriented default spawn flow | Not used by Nexa gameplay lifecycle |
| `[nexa-gameplay]/nexa_identity` | Account resolution and account state | Does not own gameplay readiness | Remains identity owner |
| `[nexa-gameplay]/nexa_characters` | Character domain and active character | Character selected is not gameplay active | Remains character owner |
| `[nexa-admin]/nexa_admin` | Admin teleport/revive/freeze/noclip foundations | Needs integration with player-state life/position exceptions | May depend on `nexa_playerstate` later; no reverse dependency |

## Findings

- No existing persistent last-position table.
- No existing server-authoritative spawn token.
- `nexa-spawn` accepts only a client request and returns a configured default point.
- `nexa-spawn` client performs fade, resurrect, coordinate application and loading-screen cleanup.
- No current lifecycle state distinguishes `character_selected`, `spawn_authorized`, `spawning`, and `active`.
- No current routing-bucket ownership model exists.
- No current life-state persistence exists outside admin recovery placeholders.
- `nexa_admin` directly performs teleport and client recovery effects after server-side authorization.

## Dependency Graph Notes

- `nexa_api` does not depend on `nexa_admin`, `nexa_identity`, `nexa_characters`, or future `nexa_playerstate`.
- `nexa_admin -> nexa_api` does not create a cycle with current manifests.
- `nexa_playerstate` may depend on `nexa-core`, `nexa_identity`, and `nexa_characters`.
- `nexa_admin -> nexa_playerstate` is allowed later for recovery/position integration.
- `nexa-core`, `nexa_identity`, and `nexa_characters` must not depend on `nexa_playerstate`.

## Migration Decision

Create `[nexa-gameplay]/nexa_playerstate` as the authoritative lifecycle owner and keep `nexa-spawn` only as a deprecated development helper until server configs are migrated.
