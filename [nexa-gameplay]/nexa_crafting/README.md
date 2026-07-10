# nexa_crafting

Server-authoritative crafting foundation for recipe definitions, stations, known recipes, jobs, quality and tool requirements.

No UI or animations are included. Inventory mutation is represented through server-owned reservations and future `nexa_inventory` transaction references. Clients cannot provide outputs, quality or completion time.

Crafting jobs are persisted with idempotency and server completion timestamps. Quality and tool validation are server-side foundation exports.

Creator/admin exports support recipe creation, activation, disable and station registration. Risky disable actions require a reason.
