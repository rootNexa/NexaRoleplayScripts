# GP18 APIs

## nexa_ui Client Exports

- `registerWindow(definition)` registers a reusable NUI window definition.
- `openWindow(id, payload)` opens a registered window.
- `closeWindow(id)` closes a registered window.
- `getOpenWindows()` returns a copy of open window payloads.
- `showLoading(payload)` shows a global loading overlay.
- `hideLoading()` hides the loading overlay.
- `showError(payload)` shows a global error overlay.
- `hideError()` hides the error overlay.

Existing exports remain available: `open`, `close`, `notify`, `menu`,
`getTheme`, `getLocale`, `registerContext`, `showContext`, `hideContext`,
`getOpenContextMenu`, `inputDialog`, `closeInputDialog`.

## nexa_beta Server Exports

- `RegisterCreator(payload)`
- `ListCreators(filter)`
- `SetFeatureFlag(key, enabled, value)`
- `GetReadiness()`
- `CollectHealth()`
- `RecordPerformanceSnapshot(payload)`
- `GetReleaseMetadata()`
- `getSchema()`
- `getStatus()`

## nexa_beta Callbacks

- `nexa:beta:cb:getReadiness`
- `nexa:beta:cb:collectHealth`
- `nexa:beta:cb:listCreators`
- `nexa:beta:cb:setFeatureFlag`
- `nexa:beta:cb:recordPerformanceSnapshot`

Callbacks use the existing Nexa callback system and return the standard
`success`, `code`, `message`, `data`, `meta` response shape.
