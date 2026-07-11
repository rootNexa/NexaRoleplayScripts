# GP18 Beta Readiness

## Included

- Shared UI primitives for GP18 windows, loading and errors.
- Creator registry and readiness foundation.
- Admin operations UI shell.
- Runtime harness.
- Static validators.
- Architecture, API, admin, creator, operations, security, performance and test
  documentation.

## Not Included

- New gameplay domains.
- Unreviewed admin mutations.
- Live FXServer certification in this repository-only pass.

## Release Gate

GP18 can be marked beta-ready after:

1. Static validators pass.
2. FXServer runtime harness passes.
3. `/nexa_admin` opens on the VPS.
4. Permissions are reviewed for any enabled admin action.
5. No critical or high security findings remain open.
