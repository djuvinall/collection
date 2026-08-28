# Architecture

This repo has no architecture in the usual sense — there is no call graph, no shared runtime, no
module that depends on another. Every file is independently invocable and knows nothing about its
siblings. So the axis that actually organizes it is **blast radius**: what a given script can do to
the machine it runs on.

That's what this document maps. `README.md` answers *"what does this script do?"*; this document
answers *"what does it touch, what does it need, and what happens if it goes wrong?"*

## Blast-radius tiers

| Tier | Meaning | Can it hurt you? |
|---|---|---|
| **0 — Pure** | Computation on inputs. No I/O beyond the pipeline. | No. |
| **1 — Read-only** | Reads filesystem, registry, CIM/WMI, or network. Changes nothing. | Only via information disclosure. |
| **2 — File-mutating** | Creates or deletes files in user-specified locations. | Recoverable. |
| **3 — System-mutating** | Registry writes, service state, scheduled tasks, protected-directory deletion, software install. | Yes. Read before running. |

## Areas

| Area | Highest tier | System surface | Detail |
|---|---|---|---|
| `powershell/Modules/` | 3 | HKCU registry, Windows Installer COM, filesystem links, AD/local auth, HTTP egress | [docs/arch/modules.md](docs/arch/modules.md) |
| `powershell/Scripts/` | 3 | winget, HTTP egress, background jobs | [docs/arch/scripts.md](docs/arch/scripts.md) |
| `powershell/functionSnippets/` | 3 | Task Scheduler (as SYSTEM), RSAT DhcpServer | [docs/arch/function-snippets.md](docs/arch/function-snippets.md) |
| `powershell/work-in-progress/` | 3 | Service control, Update COM, CIM/WMI, RSAT ActiveDirectory | [docs/arch/work-in-progress.md](docs/arch/work-in-progress.md) |
| `css/` | n/a | Firefox profile chrome | [docs/arch/css.md](docs/arch/css.md) |

## Cross-cutting

**Elevation.** No script self-elevates, and none checks for elevation except where noted. A Tier-3
script run unelevated typically fails partway through with an access-denied error, having already
made some of its changes. Assume partial application on failure unless the file says otherwise.

**`-WhatIf` support.** Four files declare `[CmdletBinding(SupportsShouldProcess)]`:
`Add-GitKeep.ps1`, `Remove-OrphanedInstallerFile.ps1`, `SetupWindowsApps.ps1`, and
`Disable-NonEssentialService.ps1` (plus `Move-SymbolicTarget` inside `SymbolicLinks.psm1`). Every
other Tier-3 script mutates immediately with no dry-run path. That asymmetry is the single most
useful thing to know before running something here on a live machine.

**External module dependencies.** Only two, both RSAT, both undeclared in their files:
`_draft.Get-DHCPReservations.ps1` needs **DhcpServer**; `work-in-progress/user_groups.ps1` needs
**ActiveDirectory**. On a machine without RSAT these fail with a bare "term is not recognized"
error that doesn't hint at the cause. Everything else runs on a stock Windows install.

**Network egress.** Three endpoints total across the repo:

| Endpoint | Reached by | Note |
|---|---|---|
| `ipinfo.io` | `Get-MyPublicIP.ps1` | Third-party; discloses your IP to them by design. |
| `axcientrestore.blob.core.windows.net` | `Download-Windows11ISO.ps1` | **Not a Microsoft endpoint.** See below. |
| winget sources | `SetupWindowsApps.ps1` | Standard package manager traffic. |

**Output convention.** Most functions return objects, not formatted text. Four exceptions:
`Get-FolderStructure.ps1` and `work-in-progress/fs_tree_scanner.ps1` render ASCII trees, where the
formatting *is* the output; `Start-Stopwatch.ps1` writes to the console by nature; and
`Get-DeNestedObject.ps1` emits everything via `Write-Host` and **returns nothing** — which makes
its output unpipeable and is arguably a defect rather than a convention. Prefer `[PSCustomObject]`
returns in anything new.

**PowerShell version.** 5.1 baseline throughout. Only `work-in-progress/fs_tree_scanner.ps1`
requires 7, and it says so in a comment rather than a `#Requires` statement.

## Boundaries that matter

These are the seams where a wrong assumption causes real damage.

**`C:\Windows\Installer` deletion.** `Remove-OrphanedInstallerFile.ps1` reconciles cached MSI/MSP
files against the Windows Installer database via the `WindowsInstaller.Installer` COM object and
deletes what it can't account for. A false positive here breaks repair/uninstall for the affected
product, and the file is not recoverable from anywhere. The reconciliation logic is the invariant —
if it's wrong, the script is actively destructive. Always `-WhatIf` first.

**Scheduled task running as SYSTEM.** `Start-InteractiveUpgrade.ps1` shells out to `schtasks.exe`
to create a task with `/ru SYSTEM /rl HIGHEST` pointing at a caller-supplied `$SetupPath`, then
runs it. Whatever path is passed executes as SYSTEM on the console desktop. Never pass an
unvalidated or user-writable path.

**Registry keys written.** Three, all under HKCU:

| Key | Written by |
|---|---|
| `HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` | `Set-Theme.ps1` |
| `HKCU:\...\Internet Settings\ZoneMap\Ranges` | `Add-TrustedSite.ps1` |
| `HKCU:\...\Internet Settings\ZoneMap\Domains\<domain>` | `Add-TrustedSite.ps1` |

`SymbolicLinks.psm1` *reads* `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock` to
detect Developer Mode but never writes it. ZoneMap entries are security-relevant: adding a site to
the Trusted zone lowers browser and Windows security policy for that origin.

**Credential handling.** `Test-Credential.ps1` has two validation methods, selected by `-Method`:
`StartProcess` (the **default**) validates locally by attempting to launch a process as the
supplied user via `System.Diagnostics.ProcessStartInfo`; `ActiveDirectory` binds against a domain
controller via `System.DirectoryServices.DirectoryEntry`. It accepts a `PSCredential` and persists
nothing — but a failed AD bind is an auditable authentication event, and repeated calls under
either method can trip account lockout policy. Derived from
[claudiospizzi/SecurityFever](https://github.com/claudiospizzi/SecurityFever).

**Third-party ISO source.** `Download-Windows11ISO.ps1` pulls a Windows 11 23H2 image from an
Axcient blob-storage URL, not from Microsoft. The comment at the top of the file points at
Microsoft's official download page, which suggests the blob was a convenience mirror. Nothing
verifies the hash of what comes down. Treat the resulting ISO as untrusted until checked against
Microsoft's published hash.

**Reading other users' profiles.** `BrowserExtensionsAudit.ps1` enumerates every non-special
`Win32_UserProfile` and reads `AppData\Local\{Google\Chrome,Microsoft\Edge}\User Data` under each.
Reading profiles other than your own requires elevation, and the output describes what software
other people have installed — scrub it before sharing.

## Known unknowns

- **`work-in-progress/` is unverified by definition.** At least one file
  (`fs_tree_scanner.ps1`) has confirmed defects; the rest have not been systematically checked.
  See [docs/arch/work-in-progress.md](docs/arch/work-in-progress.md) for what's known.
- **`Download-Windows11ISO.ps1` has a confirmed scoping bug** that makes its output path wrong —
  documented in [docs/arch/scripts.md](docs/arch/scripts.md).
- **Nothing here has ever been executed under test.** Every behavioral claim in these docs is
  derived from reading source, not from running it. Where a claim matters for safety, verify
  before relying on it.
- `test/` is reserved and empty. It's also untracked, because git does not store empty
  directories — ironic given `Add-GitKeep.ps1` lives in this repo and exists to solve exactly that.
