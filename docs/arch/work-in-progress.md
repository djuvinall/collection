# powershell/work-in-progress/

**Responsibility:** the holding pen. Incomplete, unverified, or experimental. **Assume every file
here is broken until proven otherwise.**

That warning is not boilerplate — one file has confirmed defects and none have been executed under
test. This folder contains both the least finished code in the repo *and* one of its most dangerous
scripts, which is an uncomfortable combination worth being explicit about.

## Public interface

There isn't a stable one. Two files are `.psm1` modules with no `Export-ModuleMember`, two are bare
scripts, and one is a loose function. Treat nothing here as a callable contract.

## Contracts

### `Disable-NonEssentialService.ps1` — Tier 3, most dangerous file in the repo

Disables non-essential Windows services to reduce background overhead, with a companion restore
path.

- **The admin requirement is declared but broken.** Line 1 reads literally `11#Requires
  -RunAsAdministrator` — a stray `11` precedes the directive. A `#Requires` statement must begin
  its line, so PowerShell does not treat this as a requirement at all. **The elevation check is
  not enforced.** Line 2's `#Requires -Version 5.1` is fine. This is the single most important
  correction in these docs: the most dangerous script in the repo looks guarded and isn't.
  Verified at byte level: `3131 2352 6571 7569 7265 73` = `11#Requires`.
- Two functions: `Disable-NonEssentialService` and `Restore-ServiceBaseline`.
- **Both** carry `[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]` — `-WhatIf` works.
- Three `.SYNOPSIS` blocks. By some distance the best-documented file in this folder.

**The invariant that matters:** `Restore-ServiceBaseline` is only meaningful if a baseline was
captured *before* services were disabled. Disabling without a baseline is a one-way door — you
lose the record of what the original start-up types were. Verify the baseline capture and restore
round-trip on a disposable VM before this ever touches a machine you care about.

Despite being the best-guarded script here, its blast radius (service start-up types across the
whole machine) is the largest in the repo. It is in `work-in-progress/` for good reason.

### `Get-AvailableWindowsUpdates.ps1` — Tier 1

Lists available updates via the `Microsoft.Update.Session` COM object. Read-only — no install
capability, which is the important part of its contract. No function wrapper, no parameters, no
help. Bare script.

### `Get-ComputerCPU.psm1` — Tier 1

`Get-ComputerCPU` — CPU name, manufacturer, cores, speed, socket. `[CmdletBinding()]` with a
`-ComputerName` parameter for remote queries. Notable pattern: attempts `Get-CimInstance
Win32_Processor` first and falls back to `Get-WmiObject` — sensible for reaching older targets
where WinRM/CIM isn't available.

**Its export statement is broken.** Line 59 reads `Export-Module -Function Get-ComputerCPU`.
`Export-Module` is not a PowerShell cmdlet — the real one is `Export-ModuleMember`. Importing this
file throws "The term 'Export-Module' is not recognized". This is not a missing declaration; it's
a declaration that actively errors.

### `Get-ComputerMotherboard.psm1` — Tier 1

Same shape as above against `Win32_BaseBoard`: manufacturer, product, serial, version. Same
CIM→WMI fallback, same `-ComputerName` support, and the same broken `Export-Module` call at
line 54.

These two are near-identical in structure and are the obvious candidates to merge into one
hardware-inventory module.

### `Get-DisplayMonitor.ps1` — Tier 1

Queries `Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID` for connected monitors
(manufacturer, model, serial, manufacture date). No function wrapper, no help. Note that
`WmiMonitorID` returns its string fields as **UInt16 arrays**, not strings — any consumer has to
decode them.

### `fs_tree_scanner.ps1` — Tier 1, **confirmed broken**

A TreeSize-style directory-size scanner. PowerShell 7 (stated in a comment, not a `#Requires`).
Two defects in the first ten lines:

```powershell
foreach ($drive in $possible_drives) {
    if (Test-Path $drive -eq $true) {   # (1)
        $drive += $drives               # (2)
    }
}
```

1. `Test-Path $drive -eq $true` doesn't do what it reads like. `-eq` and `$true` are consumed as
   additional positional arguments to `Test-Path`, not as a comparison. Also `$drive` here is a
   bare letter (`"A"`), not a path — it needs to be `"A:\"`.
2. `$drive += $drives` has the operands backwards. It appends the (empty) accumulator to the loop
   variable and throws the result away. Should be `$drives += $drive`.

Net effect: `$drives` is always empty and the scan never runs. The file trails off after this
block. This is a sketch, not a working script.

### `user_groups.ps1` — Tier 1

`Get-UserGroups` — AD group membership by username or email. Strips `@domain.com` if an email is
passed, verifies the user exists via `Get-ADUser`, then returns a `PSCustomObject` with `Username`
and `Groups`.

**Undeclared dependency:** requires the RSAT **ActiveDirectory** module (`Get-ADUser`,
`Get-ADPrincipalGroupMembership`). Fails with a bare "not recognized" error without it.

Two smaller issues: `snake_case` naming (`$output_Object`, `$possible_drives`) breaks the repo's
PowerShell convention, and the filename doesn't match the function it defines — everywhere else in
the repo, it would be `Get-UserGroups.ps1`.

## Data crossing the boundary

**In:** `-ComputerName` on the two hardware modules; a username or email on `user_groups.ps1`;
service names / baseline paths on `Disable-NonEssentialService.ps1`. Everything else is hardcoded.

**Out:** CIM/WMI objects mostly passed through unshaped. `user_groups.ps1` is the only one that
builds a deliberate `[PSCustomObject]`.

## Depends on

- RSAT **ActiveDirectory** — `user_groups.ps1`, undeclared.
- `Microsoft.Update.Session` COM — `Get-AvailableWindowsUpdates.ps1`.
- WinRM/DCOM for the `-ComputerName` paths on the hardware modules.
- PowerShell 7 — `fs_tree_scanner.ps1`, declared only in a comment.

## Invariants

- **Nothing leaves this folder without comment-based help, a `Verb-Noun` filename matching its
  function, and — if it mutates state — `SupportsShouldProcess`.** That's the graduation bar.
- **Nothing here is referenced by anything outside this folder.** Keep it that way; a dependency
  on unverified code is how "work in progress" quietly becomes load-bearing.
- Undeclared external module dependencies are a defect, not a style preference. Add
  `#Requires -Modules ActiveDirectory` when fixing these.

## Notes

Help coverage is 1 of 7 files (`Disable-NonEssentialService.ps1`). That's expected for a staging
folder, but it means these files are unreadable cold — the docs above are currently the only
description of what most of them do.

`Get-ComputerCPU.psm1` and `Get-ComputerMotherboard.psm1` are the two most nearly-finished files
here and the cheapest wins if you want to shrink this folder.
