# Shop Crafting Boundary

`nexa_shops` owns catalog, pricing, stock, deliveries and buy/sell transactions.

`nexa_crafting` owns recipes, stations, recipe knowledge, crafting jobs, quality and tool requirements.

Both use `nexa_items` as item definition source and `nexa_inventory` as future authoritative item movement layer. Shops do not define items. Crafting does not sell items. Economy movement belongs to `nexa_economy`.
