# Dependency Audit

## Core Foundation

| Resource | Status | Notes |
| --- | --- | --- |
| nexa_api | READY | Uses only Nexa foundation exports and no blocked legacy runtime dependencies. |

## External Runtime Dependencies

The stable foundation stack still expects `oxmysql` for database-backed foundation resources. `nexa_api` itself does not use direct database access.
