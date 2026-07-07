# [ox]

Ox-Infrastruktur-Schicht. Erwartete Phase-1-Abhaengigkeiten:

- `oxmysql`
- `ox_lib`
- `ox_inventory`
- `ox_target`
- `ox_doorlock`

`setr inventory:framework "qbx"` muss vor `ensure ox_inventory` in `server.cfg` stehen.
