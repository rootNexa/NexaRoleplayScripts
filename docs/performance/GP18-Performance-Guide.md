# GP18 Performance Guide

GP18 adds visibility without heavy loops.

## Baselines

`nexa_beta` can record performance snapshots with:

- `snapshot_key`
- `cpu_ms`
- `memory_kb`
- `net_events`
- `sql_queries`
- optional metadata

## Rules

- Avoid permanent 0-ms client or server loops.
- Admin UI refreshes on a fixed interval and can be closed cleanly.
- Health checks should be lightweight.
- Creator registry reads should be cached by callers when displayed often.
- Large diagnostic payloads should be paginated by future domain services.
