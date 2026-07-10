# Inventory Transactions

Mutationen laufen ueber geordnete In-Memory-Locks und Datenbanktransaktionen. Transfers sperren beide Inventare deterministisch nach ID, damit parallele Transfers keine Duplikation erzeugen.
