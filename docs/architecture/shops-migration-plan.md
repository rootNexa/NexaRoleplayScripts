# Shops Migration Plan

Replace the old `nexa_shops` database layer with Core DB abstraction and append-only migrations. Preserve public CRUD export names where possible, then add transaction, stock, delivery and creator exports.

Migration order:

1. Document direct database usage and old schemas.
2. Add `nexa_shop_definitions`, `nexa_shop_items`, `nexa_shop_transactions`, `nexa_shop_stock_movements`, `nexa_shop_deliveries` and `nexa_shop_audit`.
3. Register shop types in memory on resource start.
4. Add catalog, pricing, stock, buy/sell and deliveries.
5. Add validators and runtime harness.

Legacy `shops` and `shop_items` are not dropped in this chapter.
