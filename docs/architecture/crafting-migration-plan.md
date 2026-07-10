# Crafting Migration Plan

Introduce `[nexa-gameplay]/nexa_crafting` as a new server-authoritative resource. Crafting must use `nexa_items` for definitions and `nexa_inventory` for future item movement. This chapter records transactional intent and server-owned jobs; full inventory mutation can be tightened when inventory transaction APIs mature.

Migration order:

1. Add recipe/station/job/knowledge/audit tables.
2. Register crafting types.
3. Add recipe and station exports.
4. Add begin/cancel/complete job foundation, quality and tool policy.
5. Add validators and runtime harness.
