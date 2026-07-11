# GP18 Creator Guide

Creators are administrative editors for server content. GP18 registers the
available creator surfaces so admin UI and later launcher flows can discover
them consistently.

## Default Creator Types

- Jobs and organizations
- Vehicles
- Items
- Evidence
- Licenses
- Dispatch
- Hospital and medical
- Housing
- Shops
- Crafting
- Registry

## Registration Contract

Use `exports.nexa_beta:RegisterCreator(payload)` with:

- `creator_type`
- `label`
- `resource_name`
- optional `enabled`
- optional `metadata`

Creators must store real domain data in their owning resources. The creator
registry only describes availability and UI discovery metadata.
