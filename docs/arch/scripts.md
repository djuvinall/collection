# powershell/Scripts/

**Responsibility:** standalone scripts you run to accomplish a task, as opposed to functions you
load and call. Three files.

## Public interface

Invoke directly. Only one takes parameters at all.

```powershell
.\powershell\Scripts\SetupWindowsApps.ps1 -WhatIf   # supported
.\powershell\Scripts\Play-StarWarsTheme.ps1         # no params
.\powershell\Scripts\Download-Windows11ISO.ps1      # no params; edit $path first — see below
```

## Contracts

### `SetupWindowsApps.ps1` — Tier 3

Installs Devon's standard Windows application set via winget.

- `#Requires -Version 5.1`, `[CmdletBinding(SupportsShouldProcess)]`, `param()` — **`-WhatIf` works.**
- Preflights with `Test-WingetAvailable`; if winget is missing it reports that the App Installer
  needs installing rather than failing obscurely.
- Idempotent: `Test-AppInstalled` runs `winget list --id <id> --exact` before each install, so
  re-running skips what's already present.
- **Surface:** winget package installs — arbitrary vendor installers execute with whatever
  privilege winget is running under. Network egress to winget sources.
- Best-behaved script in the repo. Use it as the pattern for anything new that mutates state.

### `Play-StarWarsTheme.ps1` — Tier 0

Plays the Star Wars main theme through the console beep API. No parameters, no I/O, no risk.
It exists for fun and that's fine.

### `Download-Windows11ISO.ps1` — Tier 2, **and it has confirmed bugs**

Intended to background-download a Windows 11 23H2 x64 ISO.

```powershell
$path = ""

Start-Job -Name Win11-DL -ScriptBlock {
    $URL = "https://axcientrestore.blob.core.windows.net/win11/Win11_23H2-x64v2.iso"
    $Path = "C:\$path\Win11_23H2-x64v2.iso"
    Invoke-WebRequest -Uri $URL -OutFile $Path
}
Wait-Job -Name Win11-DL
```

Three separate defects:

1. **Scope leak.** `$path` is defined in the caller's scope but referenced inside a `Start-Job`
   script block, which runs in a *separate runspace*. `$path` is empty there regardless of what
   you set it to. Needs `$using:path` or `-ArgumentList`.
2. **`$path` is empty anyway.** Even with the scope fixed, the default is `""`, so the target
   resolves to `C:\\Win11_23H2-x64v2.iso`.
3. **Errors are swallowed.** `Wait-Job` without a following `Receive-Job` discards the job's
   output *and* its errors. A failed download looks identical to a successful one.

**Supply-chain caveat:** the ISO comes from an Axcient blob-storage URL, **not from Microsoft**.
The commented-out line at the top of the file points at Microsoft's official download page, which
suggests this was a convenience mirror. Nothing verifies the download's hash. Validate against
Microsoft's published hash before installing from it.

## Data crossing the boundary

**In:** nothing structured. `SetupWindowsApps.ps1` carries its app list inline; the other two are
fully hardcoded.

**Out:** console output and side effects. Nothing here returns pipeable objects.

## Depends on

- `SetupWindowsApps.ps1` → winget (App Installer). Degrades with a clear message if absent.
- `Download-Windows11ISO.ps1` → network reachability to the Axcient blob endpoint.
- `Play-StarWarsTheme.ps1` → nothing.

## Invariants

- **Scripts here are entry points, not libraries.** Don't add functions to this folder intended
  for reuse — those belong in `Modules/`.
- **Anything that mutates state gets `SupportsShouldProcess`.** `SetupWindowsApps.ps1` honors this;
  it's the standard for new additions.
- Job script blocks are isolated runspaces. Variables do not cross into them implicitly — this is
  the exact mistake in `Download-Windows11ISO.ps1` and it's an easy one to repeat.

## Notes

`Download-Windows11ISO.ps1` is the one file in `Scripts/` that arguably belongs in
`work-in-progress/` given its state. Left in place for now; see `tasks/todo.md`.
