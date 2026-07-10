# Properties Architecture

Nexa properties are server-authoritative real estate instances created from registered definitions. Definitions describe the published object; instances hold ownership, lease, routing, storage, garage and security state.

The architecture separates economic ownership, residential access, keys, interiors and security into clear modules. Every mutation requires actor context, reason where administrative, source resource and correlation ID. Persistent changes are audited.

The first implementation is foundation-only: no final Housing NUI, no visual furniture editor and no crime minigames.
