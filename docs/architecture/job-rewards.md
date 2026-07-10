# Job Rewards

Rewards sind serverseitig und idempotent.

Typen:

- Bankgeld
- Cash
- Item
- Organisationseinnahme
- Reputation spaeter
- XP/Skill spaeter

Jeder Reward besitzt Idempotency-Key, Status, moegliche Economy-Transaction und Inventory-Correlation. Doppelte Auszahlung ist verboten.
