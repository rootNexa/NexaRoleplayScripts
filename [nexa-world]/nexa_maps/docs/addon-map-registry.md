# Add-on-Map-Registry

Neue Add-on-Maps oder MLOs werden spaeter als eigener Resource-Ordner bereitgestellt und in `config/server.lua` registriert.

Pflichtfelder:

- `id`
- `label`
- `category`
- `resourceName`
- `assetType`
- `loadState`
- `active`
- `environment`

Regeln:

- Keine echten Marken oder echten Behoerdennamen verwenden.
- Keine Asset-Dateien in `nexa_maps` ablegen.
- Keine `data_file`- oder `files`-Deklaration in `nexa_maps` ergaenzen.
- Lade- und Kollisionsprobleme werden ueber Registry-Status dokumentiert.
- Gameplay-Logik bleibt in den dafuer vorgesehenen Resources.
