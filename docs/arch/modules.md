# powershell/Modules/

**Responsibility:** reusable functions, grouped by domain. These are the files intended to be
dot-sourced into a session and called, as opposed to run once to do a job.

Four domain folders: `git/`, `math/`, `strings/`, `utils/`. `utils/` is the catch-all and holds
everything with a system surface.

## Public interface

One function per file, filename matching the function name — with one exception. `SymbolicLinks.psm1`
is a real module and explicitly exports three functions:

```powershell
Export-ModuleMember -Function Move-SymbolicTarget, Get-SymbolicLinkTarget, Test-SymbolicLink
```

Everything else is a plain `.ps1` and exposes its function by dot-sourcing:

```powershell
. .\powershell\Modules\utils\Get-FileTypeCount.ps1
Get-FileTypeCount -Path C:\Temp
```

## Contracts by tier

### Tier 0 — Pure

| Function | Contract |
|---|---|
| `math/Get-CompoundedValue` | principal, rate, periods → compounded value. No I/O. |
| `strings/Get-UpperCase` | string(s) in → uppercased out. Pipeline-friendly. |
| `strings/Invoke-StringScramble` | string in → character-shuffled string out; can pin specified characters in place. Non-deterministic by design. |
| `utils/Get-DeNestedObject` | arbitrarily nested object/JSON in → flattened structure **printed via `Write-Host`**. Returns nothing; output is not pipeable. Debugging aid only. |
| `utils/Start-Stopwatch` | countdown/elapsed timer. Console output only. |

### Tier 1 — Read-only

| Function | Reads | Notes |
|---|---|---|
| `utils/Get-FolderStructure` | Filesystem tree | Returns rendered ASCII text, not objects. Optional file inclusion. |
| `utils/Get-FileTypeCount` | Filesystem tree | Per-extension stats: count, total/avg size, date range, % of total. |
| `utils/Get-MyPublicIP` | `https://ipinfo.io` | **Network egress.** Discloses your IP to a third party. No error handling — throws on no connectivity. |
| `utils/BrowserExtensionsAudit` | CIM `Win32_UserProfile`; per-profile Chrome/Edge `User Data` dirs | **Needs elevation** to read profiles other than the current user's. Output names third-party software per user — scrub before sharing. |
| `utils/Test-Credential` | `-Method StartProcess` (**default**) → `System.Diagnostics.ProcessStartInfo`, local. `-Method ActiveDirectory` → `System.DirectoryServices.DirectoryEntry`, binds a DC. | **Handles credentials.** Failed attempts count toward lockout policy; failed AD binds are auditable auth events. Derived from claudiospizzi/SecurityFever. |

### Tier 2 — File-mutating

| Function | Writes | Guard |
|---|---|---|
| `git/Add-GitKeep` | `.gitkeep` files into empty directories, recursively | `SupportsShouldProcess` — `-WhatIf` works. |

### Tier 3 — System-mutating

| Function | Surface | Guard |
|---|---|---|
| `utils/Set-Theme` | Writes `HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`; stops and restarts `explorer.exe` | **None.** No `-WhatIf`. |
| `utils/Add-TrustedSite` | Writes `HKCU:\...\Internet Settings\ZoneMap\Ranges` and `ZoneMap\Domains\<domain>` | **None.** No `-WhatIf`, no `[CmdletBinding()]` at all. |
| `utils/Remove-OrphanedInstallerFile` | `WindowsInstaller.Installer` COM; **deletes** from `C:\Windows\Installer` | `SupportsShouldProcess`, `ConfirmImpact = 'High'`. Admin required. |
| `utils/SymbolicLinks.psm1` | Creates/moves NTFS symbolic links; reads `HKLM:\SOFTWARE\...\AppModelUnlock` to detect Developer Mode | `Move-SymbolicTarget` has `SupportsShouldProcess`. `#Requires -Version 5.1`. Admin **or** Developer Mode. |

## Data crossing the boundary

**In:** paths, strings, numbers, `PSCredential` objects. Nothing reads from a config file or
environment variable — every input is an explicit parameter.

**Out:** objects, except `Get-FolderStructure` (rendered text) and `Start-Stopwatch` (console
writes). `BrowserExtensionsAudit` emits structured output shaped for IT inventory ingestion —
it was written with ConnectWise ASIO in mind.

## Depends on

Nothing outside a stock Windows PowerShell 5.1 install. No RSAT, no external modules, no
PSGallery packages. This is worth preserving — it's what makes these safe to paste into an
unfamiliar machine's console.

## Invariants

- **One function per file, filename == function name.** Dot-sourcing by path is the only discovery
  mechanism there is; breaking this makes functions unfindable.
- **Tier-0 and Tier-1 functions must stay side-effect free.** `utils/` is the only folder where a
  system surface is expected. A registry write appearing in `strings/` would be a design break.
- **`SymbolicLinks.psm1`'s export list is the contract.** Functions not in `Export-ModuleMember`
  are private — adding a function without exporting it makes it unreachable via `Import-Module`.
- **No self-elevation.** Scripts fail on insufficient privilege rather than prompting for UAC.

## Notes

- `Set-Theme.ps1` documents a known cosmetic issue in its own help: the `Stop-Process` on
  `explorer.exe` may emit "Access Denied" but the restart succeeds anyway, and a stray File
  Explorer window may open as a side effect.
- `Add-TrustedSite.ps1` has no `[CmdletBinding()]` — it's the least-hardened Tier-3 function here
  despite writing security-zone policy. Worth fixing.
- `Get-MyPublicIP.ps1` is two lines with no error handling and no comment-based help.
- ZoneMap writes are HKCU, so they affect the current user only and don't require elevation. That
  makes this function *easier* to run than its blast radius suggests.
