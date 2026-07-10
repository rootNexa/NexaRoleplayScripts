# Player State Migration Plan

## Goal

Introduce `nexa_playerstate` as the server-authoritative gameplay lifecycle and spawn service while preserving the separation between sessions, accounts, characters, and gameplay readiness.

## Steps

1. Document current spawn/state ownership.
2. Add `nexa_playerstate` resource with lifecycle state machine.
3. Add Core DB migrations for character position and life state.
4. Implement spawn providers: last position and safe fallback.
5. Implement source/character-bound spawn token authorization.
6. Add client spawn executor with no decision authority.
7. Add position snapshots, routing buckets, and life-state foundation.
8. Update admin recovery to integrate with player-state life-state when available.
9. Add runtime test harness and validators.
10. Update development start order to include `nexa_playerstate`.

## Compatibility

- `nexa-spawn` can remain installed but should not be the production lifecycle owner.
- New resources should use `exports.nexa_playerstate:IsPlayerReadyForGameplay(source)`.
- Admin teleport may continue to perform movement, but should notify playerstate before/after legitimate jumps in a later hardening pass.

## Removal Criteria for `nexa-spawn`

- `nexa_playerstate` starts cleanly.
- Spawn is token-bound and character-bound.
- Runtime tests cover fallback spawn and last-position spawn.
- Development config no longer needs `nexa-spawn`.

## Runtime Limits

FXServer live tests are required for real loading-screen, collision, resurrect, statebag and disconnect behavior.
