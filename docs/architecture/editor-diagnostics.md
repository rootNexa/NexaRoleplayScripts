# Editor Diagnostics

Current workspace diagnostics include built-in `[cfx]` resources and legacy resources. Built-in CFX resources should not be edited for cosmetic diagnostics.

Known real Nexa diagnostics from this chapter:

- old `nexa_shops` had direct `oxmysql` imports and `MySQL.*` calls
- no `nexa_crafting` resource existed

The fix is resource-level architecture cleanup, not global warning suppression.
