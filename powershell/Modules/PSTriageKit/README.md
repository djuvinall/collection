# PSTriageKit

Incident-response triage toolkit that collects host data into protected PTK bundles and provides readers, exporters, and a constrained query interface.

## Requirements
- Windows PowerShell 5.1+ (compatible with PowerShell 7+)
- No external dependencies; uses built-in CIM/crypto/cmdlets

## Install / Import
```powershell
# From the repo root
Import-Module .\PSTriageKit\PSTriageKit.psd1 -Force
```

## Quick start
```powershell
# Collect (gzip only) and zip the bundle
Invoke-TriageCollection -OutputPath .\out -Protect Compress -Zip

# Collect with password protection
$pw = Read-Host -AsSecureString
Invoke-TriageCollection -OutputPath .\out -Protect Password -Password $pw -Zip

# Load a bundle (folder or zip)
$c = Get-TriageCollection -Path .\out

# Show a concise summary
Show-TriageSummary -Collection $c

# Query all processes for names containing "powershell"
Find-TriageData -Collection $c -Query 'Collector=Processes Where Name~powershell' -Limit 50

# Query hardware inventory (e.g., GPU contains NVIDIA)
Find-TriageData -Collection $c -Query 'Collector=HardwareInventory Where Gpu.Name~NVIDIA'

# Export decrypted data to JSON files
Export-TriageData -Collection $c -Path .\exports -Format Json
```

## Protection modes and PTK format
- `Compress` (default): UTF-8 JSON -> gzip payload bytes
- `Password`: UTF-8 JSON -> gzip -> AES-256-CBC (PBKDF2-HMACSHA256 key derivation, HMAC-SHA256 authentication)
- PTK layout: magic `PSTKPTK1` + header length (UInt32 LE) + header JSON + payload bytes. Header records collector name, createdUtc, protect/compression/encoding info, and crypto metadata/mac when passworded.

## Public commands
- `Invoke-TriageCollection`: run collectors, write PTK files, index, logs, hashes, optional zip. Key parameters: `-OutputPath`, `-Profile`, `-Collectors`, `-ExcludeCollectors`, `-SinceHours`, `-Protect Compress|Password`, `-Password`, `-Zip`, `-Force`.
- `Get-TriageCollection`: load a bundle folder or zip (auto-extracts when zip given). Returns metadata and PTK file list.
- `Get-TriageData`: unpack PTKs for one/all collectors; supports `-Password` when needed and `-AsHashtable` for keyed results.
- `Export-TriageData`: write decrypted data to Json or Csv files per collector.
- `Show-TriageSummary`: returns a concise summary object (OS, uptime, users/admins, services, processes, recent events, Defender).
- `Find-TriageData`: constrained query across unpacked objects; supports collector filter, simple Where expressions, projection, `-Limit`, and `-IncludeRaw`.
- `Get-TriageCollector`: list available collector scripts.
- `Test-TriagePrereq`: quick capability checks (PowerShell version, crypto primitives).
- `New-TriageProfile`: create JSON profiles to preset include/exclude lists.

## Collector set (MVP)
- SystemInfo, UsersAndGroups, Processes, Services, ScheduledTasks, Networking, Firewall, EventLogs (System/Application; Security if admin; 72h critical/error/warn window with skip reasons), DefenderStatus, AutorunsLite (Run keys + startup folders), HardwareInventory (CPU/GPU/board/BIOS/RAM/disks/NICs/controllers/PnP drivers/peripherals).

## Bundle layout
- `index.json` – minimal metadata (tool version, host, protect mode, collectors run/skipped)
- `run.log.jsonl` – structured run log (no secrets)
- `hashes.sha256` – SHA256 of every file in bundle
- `Collectors/<Collector>.ptk` – one per collector
- Optional `<bundle>.zip` when `-Zip` is used

## Query language (Find-TriageData)
- Form: `Collector=<name> Where <conditions> | Select <fields>` (Select optional)
- Operators: `=`, `!=`, `~` (substring match), `in (a,b,c)`, logical `and` (basic split). Parentheses not supported in this minimal parser.
- Examples:
  - `Collector=Processes Where Name~powershell | Select Name,Id,Path`
  - `Collector=HardwareInventory Where Cpu.Name~Intel`
  - `Collector=EventLogs Where Level=Error and ProviderName~TPM`
  - `Where EventId in (4625,4688) and Level="Error"`

## Profiles
- JSON files under `Profiles/` (e.g., `Profiles/default.json`) with fields: `name`, `collectors` (include list), `exclude`.
- Create via `New-TriageProfile -Name quick -Collectors Processes,Services`.

## Tests
Run the suite:
```powershell
Invoke-Pester -Path .\PSTriageKit\tests
```
Coverage includes PTK pack/unpack (compress + password), wrong-password auth failure, bundle creation, and basic query matching.

## Notes
- Safe/read-only: collectors avoid system changes; privileged-only data is skipped with reasons recorded.
- Password-protected PTKs require the same password for read/export/query; authentication failures surface clearly.
