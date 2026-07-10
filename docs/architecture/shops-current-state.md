# Shops Current State

`[nexa-gameplay]/nexa_shops` exists as an early foundation. It still imports `@oxmysql/lib/MySQL.lua`, depends directly on `oxmysql`, `nexa_api` and `nexa_logs`, and uses direct `MySQL.*.await` calls. The tables are `shops` and `shop_items`, without the full Nexa-prefixed commerce model.

It supports basic shop CRUD and shop item CRUD. It does not yet own shop types, server-side pricing policies, stock reservations, transaction sagas, deliveries, organization shop rules, illegal shop access, creator lifecycle, or audit.

No complete crafting foundation exists in `[nexa-gameplay]`.
