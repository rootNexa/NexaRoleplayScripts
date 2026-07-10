# Playerstate Testing

Static validators:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-playerstate-foundation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-playerstate-lifecycle.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-playerstate-security.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-playerstate-runtime-harness.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\validate-resource-dependency-graph.ps1
```

Runtime tests require FXServer and safe test characters.
