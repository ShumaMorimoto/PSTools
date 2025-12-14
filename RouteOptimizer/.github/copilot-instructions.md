## RouteOptimizer - Copilot/AI Instructions

Summary
- **What**: PowerShell module for GPX creation, geographic lookup (Nominatim/Overpass), and route optimization (GA/greedy). Includes GUI (WPF/WinForms) and a web-based Leaflet map for interactive editing.
- **Primary entry**: `RouteOptimizer.psm1` (defines `GPXDocument`, `GPXDocumentFactory`, loads `Public/`, `Private/`, `Common/`, and exports `Public/*` cmdlets).

Key Components
- `RouteOptimizer.psm1`: central class implementations and module loader. Inspect first for top-level architecture.
- `Classes/`: helper PS classes (`GPXDocument`, `GPXDocumentFactory` are implemented in the module but related helpers are placed here).
- `Public/`: exported cmdlets (function file name → exported function). Use this folder to add new user-facing commands.
- `Private/`: internal helpers used by GA, distance calc and other algorithms (not exported).
- `Common/SettingsManager.ps1`: responsible for settings path, ProgramData-based defaults and `Enable-ModuleSettings`.
- `data/map.html`: interactive Leaflet UI template used by `Choice-Places` to edit map points. Template placeholders: `$CenterLat`, `$CenterLng`, `$Zoom`, `$MapData`.
- `Sample/`: runnable sample scripts helpful for manual testing (e.g., `Start-PlaceSearchTool.ps1`, `Optimize-Gpx.ps1`).

Patterns & Conventions
- Public API: Put user-facing cmdlets in `Public/` with PascalCase function names and appropriate `param()` blocks. They’ll be auto-exported by the module loader.
- XML PSO Expansion: `GPXDocument::CreateElementFromPSO()` is commonly used to convert PSCustomObjects/hash tables to XML nodes—follow this pattern to generate `trkpt` and `extensions` nodes.
- Networking: Use `Invoke-RestMethod` to call Nominatim / Overpass. `GPXDocumentFactory` centralizes API URLs and headers (see `NominatimSearchUrl`, `OverpassUrl`, `ApiHeaders`).
- Concurrency: `ResolveLocations()` uses `ForEach-Object -Parallel` with `-ThrottleLimit 20`. Ensure PowerShell 7+ for parallel pipeline support; otherwise operations use the serial path.
- UI/Flow: `Choice-Places` spawns an `HttpListener` on `http://localhost:5000/` and opens `data/map.html` in the browser. Map posts edits back to `/choice` and signals completion at `/done`.

Developer Workflows
- Quick local dev: `Import-Module .\RouteOptimizer.psm1 -Force` then run functions from `Public/` or `Sample/`.
- Manual tests: `Start-PlaceSearchTool.ps1` (WPF UI), `Sample/Optimize-Gpx.ps1` and `Choice-Places` for map-driven editing.
- Debugging tips: use `Write-Host`, `Write-Verbose`, `Write-Warning`, and `Invoke-WithRetry` wrapper for reliable network calls; use `Get-Command -Module RouteOptimizer` to list exports.
- Settings: update `Templates/DefaultSettings.json` to change defaults and use `Enable-ModuleSettings` to read/write settings under `%ProgramData%`.

Integration & External Dependencies
- Web mapping: `data/map.html` references Leaflet, Leaflet-ExtraMarkers, and FontAwesome via CDNs. Local edits use the `Choice-Places` HTTP listener at port 5000.
- Geo APIs: `https://nominatim.openstreetmap.org/` (reverse/search) and `https://overpass-api.de/api/interpreter` (Overpass). Respect API rate limits.
- UI libs: `System.Windows.Forms`, `System.Drawing`, and `PresentationFramework` (WPF) are used. The module is primarily Windows-focused.
- Optional native lib: `lib/*.dll` are added via `Add-Type` when present.

Code Patterns to Watch For
- Keep `Public/*` functions small: they orchestrate UI or call `GPXDocumentFactory`/`Get-*` helpers.
- `GPXDocument` subclasses `XmlDocument` — methods like `AppendTrkPt`, `SetTrkName`, and `UpdateStats` mutate the XML. Tests should treat the XML structure as the surface-level contract.
- ID handling in `FromMapEdit()` / `Choice-Places`: map edits include `id` when updating existing trkpt nodes; new points have `null` ID. Maintain `id` if present.
- `Get-TotalDistance` supports `RouteMode` (`Open`, `Circle`, `Free`) — be consistent with callers.

Common Tasks Examples
- Import and list functions:
```powershell
Import-Module .\RouteOptimizer.psm1 -Force
Get-Command -Module RouteOptimizer
```
- Run map editor (example using factory):
```powershell
$gpx = [GPXDocumentFactory]::FromMap("京都市")
$points = $gpx.GetTrkPts() | ForEach-Object {
    @{ id = $_.GetAttribute('id') ; lat = $_.lat ; lon = $_.lon ; name = $_.name ; desc = $_.desc ; extended = $_.extensions }
}
Choice-Places -Place $null -Points $points
```

Gotchas & Notes
- The codebase uses some PowerShell 7+ features (`ForEach-Object -Parallel`) and Windows-only features (`System.Windows.Forms`, WPF). Prefer PowerShell 7 on Windows for development.
- Network calls use external APIs — tests and local development may be rate-limited or require a stable internet connection. Use `Invoke-WithRetry` to handle API flakiness.
- The HTML template uses JS to PUT/POST to fixed endpoints. To change behavior, edit `Public/Choice-Places.ps1` or the template variables in `data/`.

Where to Make Changes
- Add a new cmdlet: `Public/Your-VerbNoun.ps1` → ensure `param()` and `CmdletBinding()` if needed.
- Add internal utilities: `Private/` or `Classes/` if complex; prefer `GPXDocument` methods for XML manipulations.
- Add sample/test flows: extend `Sample/` scripts for reproducible manual tests.

If unclear or missing details — ask for specifics (PowerShell version, typical runtime environment, or examples of how you'll be using the module).

End of Guidelines
