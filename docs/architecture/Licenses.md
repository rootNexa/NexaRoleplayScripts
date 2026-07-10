# GP16 Licenses

`nexa_licenses` besitzt License Types, Character Licenses und History.

## States

License: `pending -> active -> suspended -> active -> revoked`, optional `expired`.

## APIs

Exports: `RegisterLicenseType`, `ListLicenseTypes`, `IssueLicense`, `SuspendLicense`, `ReinstateLicense`, `RevokeLicense`, `ExpireLicense`, `ValidateLicense`, `GetLicenseHistory`.

MDT und Documents duerfen Lizenzstatus lesen, aber nicht als eigene Wahrheit speichern.
