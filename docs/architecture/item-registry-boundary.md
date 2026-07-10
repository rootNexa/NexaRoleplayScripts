# Item Registry Boundary

`nexa_items` definiert Itemarten. `nexa_inventory` besitzt konkrete Instanzen.

`nexa_items` darf nicht von `nexa_inventory` abhaengen. `nexa_inventory` darf `nexa_items` fragen: Gewicht, Stackbarkeit, MaxStack, Nutzbarkeit, Drop/Trade/Quickslot-Flags, Metadatenvalidierung und Clientdefinition.
