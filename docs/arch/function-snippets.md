# powershell/functionSnippets/

**Responsibility:** small single-purpose functions and sketches that haven't earned a domain folder
under `Modules/`. Four files, and the tier spread here is wider than the folder name suggests —
one of these is the highest-privilege operation in the repo.

The `_draft.` filename prefix marks a file that is a sketch rather than a working function.

## Public interface

Dot-source, same as `Modules/`:

```powershell
. .\powershell\functionSnippets\Test-IsInteractiveSession.ps1
```

`_draft.Get-DHCPReservations.ps1` is the exception — it's a bare pipeline, not a function, so
dot-sourcing it *executes* it rather than defining anything.

## Contracts

### `Test-IsInteractiveSession.ps1` — Tier 1

Returns whether PowerShell is running in an interactive user session versus a SYSTEM or service
context. Has comment-based help. No parameters, no side effects.

This is the natural guard for the other snippets here — an RMM/SYSTEM context is precisely when
`Start-InteractiveUpgrade` becomes relevant.

### `Get-SearchMsUncPath.ps1` — Tier 0

Extracts UNC paths from Windows `search-ms:` URIs. Pure string parsing. No comment-based help.

### `Start-InteractiveUpgrade.ps1` — Tier 3, **highest-privilege operation in the repo**

Creates and immediately runs a scheduled task so Windows Setup can execute interactively when
invoked from a non-interactive context (RMM backstage, SYSTEM).

**Surface:** shells out to `schtasks.exe` — not the `ScheduledTasks` PowerShell module — to:

1. `schtasks /delete /tn Win11_Interactive_Upgrade /f` (silently, errors suppressed)
2. `schtasks /create ... /ru "SYSTEM" /rl HIGHEST /f` with `/tr "<SetupPath> <Arguments>"`
3. `schtasks /run /tn Win11_Interactive_Upgrade`

**Parameters:**

| Name | Required | Default |
|---|---|---|
| `SetupPath` | yes | — |
| `Arguments` | no | `/Auto Upgrade /Quiet /MigrateDrivers all /DynamicUpdate Disable /Telemetry disable /compat IgnoreWarning /ShowOOBE none /NoReboot /eula accept` |

**The boundary that matters:** `$SetupPath` is interpolated straight into the task's command line
and executes **as SYSTEM at highest privilege**. There is no validation that the path exists, is
signed, or lives somewhere unprivileged users can't write. Passing an attacker-controlled or
user-writable path is a straightforward local privilege escalation. Only ever pass a path you
control.

Secondary notes: the fixed task name means a second invocation destroys the first's task without
warning. The whole body is wrapped in a `try/catch` that only writes a colored message, so failure
is non-fatal and easy to miss. Requires admin. No `-WhatIf`.

### `_draft.Get-DHCPReservations.ps1` — Tier 1, draft

```powershell
Get-DhcpServerv4Scope |
  ForEach-Object { Get-DhcpServerv4Reservation -ScopeId $_.ScopeId } |
  Select-Object ScopeId,IPAddress,ClientId,Name,Description,Type
```

Three lines, read-only, and genuinely useful — but not a function, so it can't be dot-sourced or
parameterized. There's no `-ComputerName`, so it only queries the local DHCP server.

**Undeclared dependency:** requires the RSAT **DhcpServer** module. Without it, this fails with
`The term 'Get-DhcpServerv4Scope' is not recognized` — an error that doesn't hint at the real
cause. Nothing in the file says so.

## Data crossing the boundary

**In:** a setup path and argument string (`Start-InteractiveUpgrade`); a `search-ms:` URI
(`Get-SearchMsUncPath`). The other two take nothing.

**Out:** `Test-IsInteractiveSession` returns a boolean. `_draft.Get-DHCPReservations` returns
reservation objects. `Start-InteractiveUpgrade` returns nothing and reports via `Write-Host`.

## Depends on

- `schtasks.exe` — in-box on all supported Windows.
- RSAT **DhcpServer** module — `_draft.Get-DHCPReservations.ps1` only, and undeclared.

## Invariants

- **`_draft.` means not-yet-a-function.** Removing the prefix implies it's been wrapped in a
  proper `function` block with parameters and help.
- **Snippets graduate to `Modules/<domain>/` once they're stable and reused.** This folder is a
  waiting room, not a destination.
- **`Start-InteractiveUpgrade`'s caller owns path validation.** The function does none. If that
  ever changes, update this file — it's the security-relevant contract.

## Notes

Two of four files have comment-based help (`Start-InteractiveUpgrade`, `Test-IsInteractiveSession`).

`Start-InteractiveUpgrade.ps1` and `Test-IsInteractiveSession.ps1` are the two most obviously
MSP-derived files in the repo. Both are generic enough to be public safely — no client names,
hostnames, or tenant identifiers — which is the bar anything else derived from work needs to clear.
