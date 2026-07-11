# GP18 Admin Guide

`nexa_admin_ui` is the GP18 operations surface. Open it with:

```text
/nexa_admin
```

The initial UI is read-only and shows readiness, resource health, creator count
and section navigation. It is a shell for later secured workflows and must not
bypass domain services.

## Sections

- Overview
- Players
- Characters
- Vehicles
- Inventories
- Housing
- Businesses
- Dispatch
- MDT
- Evidence
- Banking
- Logs
- Security
- Performance
- Feature Flags
- Diagnostics

## Security Rule

Every future mutation must be implemented server-side by the owning resource,
checked with Nexa permissions and audited. The client is never authoritative.
