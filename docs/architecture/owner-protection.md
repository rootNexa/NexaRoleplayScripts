# Owner Protection

## Rules

- Only Owner may assign or remove `owner`.
- Co-Owner cannot mutate Owner.
- Head Admin cannot assign or remove Owner or Co-Owner.
- Lower roles cannot mutate equal or higher roles.
- Actors cannot grant themselves higher rights.
- The last Owner cannot be removed.
- Owner mutations are audited with action-specific records.

## Bootstrap

Owner bootstrap must be explicit and server-side:

- No committed license identifier.
- No IP or hardware identifier.
- Optional ACE bootstrap may be used through `nexa.permissions.bootstrap_owner`.
- Optional console assignment can be used during controlled setup.
- Bootstrap should be disabled after the initial Owner exists.

## Recovery

If all Owner access is lost due to operational error, recovery is an ops procedure using console or database access. The recovery action must be documented in audit notes immediately after access is restored.
