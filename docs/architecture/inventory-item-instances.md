# Inventory Item Instances

Itemdefinition und Iteminstanz sind getrennt. `water` ist eine Definition; ein Stack Wasser im Slot 3 ist eine Instanz. Nicht stackbare Items, Container, Dokumente, Schluessel und Waffen brauchen stabile `instance_id`.

Stacks duerfen nur zusammengelegt werden, wenn Itemname, Metadaten, Haltbarkeit, Ablaufzeit und Stackregeln kompatibel sind.
