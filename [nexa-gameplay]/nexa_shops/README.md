# nexa_shops

Server-authoritative shop and commerce foundation. It owns shop definitions, catalog, pricing, stock, buy/sell transaction records, deliveries, creator lifecycle and audit.

No UI, NPCs or markers are included. Economy movement is represented through `nexa_economy` references and item movement through `nexa_inventory` references; clients never provide final prices, stock or transaction results.

Buy/sell APIs create transaction rows with idempotency and correlation IDs. Retry and compensation exports are foundation hooks for later full economy/inventory saga recovery.
