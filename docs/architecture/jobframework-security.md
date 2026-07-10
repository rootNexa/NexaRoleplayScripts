# Jobframework Security

Verboten:

- Client setzt Progress frei.
- Client setzt Completion frei.
- Client bestimmt Reward.
- Client sendet freie Character-ID.
- Client bestimmt Route, Task oder Phase.
- Freie Handlernamen aus Datenbankwerten.
- Dynamische Codeausfuehrung.

Erlaubt sind nur kontrollierte Requests mit Source-Bindung, Rate-Limit und serverseitiger Validierung.
