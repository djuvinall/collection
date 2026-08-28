# collection

Devon's personal grab-bag of reusable code — mostly Windows PowerShell utilities, plus one
Firefox `userChrome.css` tweak. This is a **reference library, not an application**: the files
here are independent of one another, have no shared runtime, and are meant to be looked up,
copied, or dot-sourced on demand. Several utilities double as tooling for MSP / Friends-&-Family
IT support work.

Public repo: <https://github.com/djuvinall/collection> — released under The Unlicense.

**North star:** any script here can be found and reused in under a minute, and future-me can
tell at a glance whether it's safe to run on a live machine.
**Status:** active

## Working agreement

- **`README.md` is the catalog** — what each script does, in plain language, organized by folder.
  **`ARCHITECTURE.md` is the system-surface map** — what each area *touches* (registry keys, CIM
  classes, COM objects, network endpoints), what it requires, and what it can break. They answer
  different questions. Don't merge them, and don't copy entries between them.
- When adding or removing a script, update `README.md`. When a script's **system surface** changes
  — a new registry write, a new COM object, a new external module dependency, a change in
  elevation requirement — update the matching `docs/arch/` file in the same change. A stale
  surface map is worse than none, because it gets trusted for safety decisions.
- Check `tasks/todo.md` before starting something new.
- Record non-obvious lessons in `tasks/lessons.md` — a PowerShell footgun that cost an hour will
  cost the next session an hour too.
- `tasks/scratchpad.md` is disposable. Nothing in it is decided.
- Structural calls (reorganizations, splitting something out to its own repo) go in `decisions.md`
  with the reasoning. Git history records *what* moved; it doesn't record *why*.

## Stack

- **Windows PowerShell 5.1** is the baseline target. Most utilities also run clean on PowerShell 7.
- PS7-only scripts must say so — currently only `work-in-progress/fs_tree_scanner.ps1`.
- **One Python file exists on `origin` (`python/convert-har_to_csv.py`) but is not in the local
  checkout** — the working copy is a commit behind. Pull before trusting the layout below. These
  docs were written against the local state and do not describe it.
- No external PowerShell modules are required *except* where explicitly noted: two scripts need
  RSAT (see `docs/arch/` for which). There are no package manifests, no build system, and no
  dependency lockfile — by design.
- Windows-only. Nothing here is expected to run on Linux or macOS.

## Layout

```
collection/
├── css/                  Firefox userChrome customization
├── docs/arch/            System-surface detail, one file per area
├── powershell/
│   ├── Modules/          Reusable functions, grouped by domain (git, math, strings, utils)
│   ├── Scripts/          Standalone runnable scripts
│   ├── functionSnippets/ Single-purpose snippets and drafts
│   └── work-in-progress/ Incomplete / experimental — assume broken
├── python/               On origin only — not in local checkout, undocumented
├── tasks/                Working state (todo, lessons, scratchpad)
└── test/                 Reserved, empty
```

### Where a new file goes

| If it is… | Put it in |
|---|---|
| A reusable function you'd dot-source into a session | `powershell/Modules/<domain>/` |
| Something you invoke directly to do a job | `powershell/Scripts/` |
| A small snippet, or a function not yet earning a domain folder | `powershell/functionSnippets/` |
| Unfinished, unverified, or experimental | `powershell/work-in-progress/` |

Naming: PowerShell `Verb-Noun` with an approved verb (`Get-Verb` lists them), **singular noun**,
one function per file, filename matching the function name. Prefix with `_draft.` for a file that
is a sketch rather than a working function. Plain `.ps1` files under `Modules/` are single-function
files meant to be dot-sourced; `.psm1` files are real modules meant to be `Import-Module`'d.

## Verification

There is no test framework and no build step. Before committing, at minimum parse-check the file —
this needs nothing installed:

```powershell
# Syntax check a single file
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path .\path\to\Script.ps1), [ref]$null, [ref]$errors)
$errors

# Parse-check everything
Get-ChildItem -Recurse -Include *.ps1,*.psm1 | ForEach-Object {
    $e = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$e)
    if ($e) { [PSCustomObject]@{ File = $_.Name; Errors = $e.Count } }
}
```

Anything that mutates system state must be manually smoke-tested, and must support `-WhatIf` via
`[CmdletBinding(SupportsShouldProcess)]` before it leaves `work-in-progress/`.

TBD — PSScriptAnalyzer is not currently set up. If it gets added, `Invoke-ScriptAnalyzer -Recurse`
becomes the real lint gate and this section should be updated to say so.

## Constraints

- **This repo is public.** Never commit client names, real hostnames, internal IP ranges, tenant
  IDs, usernames, or credentials. MSP work context is the reason to be deliberate here — scripts
  can be *derived* from work problems, but must be scrubbed and generic before landing.
- PowerShell 5.1 compatibility is the default. No ternaries, no `??`, no `-Parallel`, no
  `ConvertFrom-Json -AsHashtable` unless the file declares `#Requires -Version 7`.
- Every function gets comment-based help (`.SYNOPSIS` at minimum). Currently 14 of 29 files have
  it — that gap is tracked in `tasks/todo.md`.
- Destructive operations require `SupportsShouldProcess` and a documented `-WhatIf` path.

## Out of scope

- **Not a distributable module.** No `.psd1` manifests, no PSGallery publishing, no semantic
  versioning. Don't propose adding them.
- **Not a home for real projects.** When something here grows past a few hundred lines and
  develops its own structure, it graduates to its own repo. This has already happened twice —
  see `decisions.md`. Don't rebuild an extracted project in here.
- **No CI.** No GitHub Actions, no automated test runs. The verification gate above is manual and
  that's intentional for a repo of this size.
- Cross-platform support. Windows-only, permanently.
