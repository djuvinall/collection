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
**Visibility:** public

## Working agreement

- **`README.md` is the catalog** — what each script does, in plain language, organized by folder.
  **`ARCHITECTURE.md` is the system-surface map** — what each area *touches* (registry keys, CIM
  classes, COM objects, network endpoints), what it requires, and what it can break. They answer
  different questions. Don't merge them, and don't copy entries between them.
- When adding or removing a script, update `README.md`. When a script's **system surface** changes
  — a new registry write, a new COM object, a new external module dependency, a change in
  elevation requirement — update the matching `docs/arch/` file in the same change. A stale
  surface map is worse than none, because it gets trusted for safety decisions.
- Check the work queue (below) before starting something new. `tasks/todo.md` holds only
  session-level notes too small for an issue.
- Record non-obvious lessons in `tasks/lessons.md` — a PowerShell footgun that cost an hour will
  cost the next session an hour too.
- `tasks/scratchpad.md` is disposable. Nothing in it is decided.
- Structural calls (reorganizations, splitting something out to its own repo) go in `decisions.md`
  with the reasoning. Git history records *what* moved; it doesn't record *why*.

## Stack

- **Windows PowerShell 5.1** is the baseline target. Most utilities also run clean on PowerShell 7.
- PS7-only scripts must say so — currently `work-in-progress/fs_tree_scanner.ps1` and
  `Modules/ai/OllamaChat.psm1` (`#Requires -Version 7.4`; CI parse-checks it under pwsh, not 5.1).
- One Python file, `python/convert-har_to_csv.py`. It is not yet catalogued in `README.md` or
  mapped in `ARCHITECTURE.md`.
- No external PowerShell modules are required *except* where explicitly noted: two scripts need
  RSAT (see `docs/arch/` for which). There are no package manifests, no build system, and no
  dependency lockfile — by design.
- Windows-only. Nothing here is expected to run on Linux or macOS.

## Layout

```
collection/
├── css/                  Firefox userChrome customization
├── docs/arch/            System-surface detail, one file per area
├── palettes/             Color palettes / themes (JSON)
├── powershell/
│   ├── Modules/          Reusable functions, grouped by domain (ai, git, math, strings, utils)
│   ├── Scripts/          Standalone runnable scripts
│   ├── functionSnippets/ Single-purpose snippets and drafts
│   └── work-in-progress/ Incomplete / experimental — assume broken
├── python/               One HAR → CSV converter, not yet documented
├── tasks/                Working state (todo, lessons, scratchpad)
└── test/                 Reserved, empty — untracked, so absent on a fresh clone
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
this needs nothing installed. **Run it in Windows PowerShell 5.1 (`powershell.exe`), not pwsh 7:**
pwsh's parser accepts PS7-only syntax and BOM-less UTF-8 that 5.1 rejects, so a pwsh run passes
files that are broken on the baseline. CI (`.github/workflows/ci.yml`) runs the same check under
5.1.

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
  `ConvertFrom-Json -AsHashtable`, no `?.` unless the file declares `#Requires -Version 7`.
- A `.ps1`/`.psm1` containing any non-ASCII character (em dash, box-drawing, smart quote) must be
  saved as **UTF-8 with BOM**. Without the BOM, 5.1 reads it as ANSI and the file can fail to parse.
- Every function gets comment-based help (`.SYNOPSIS` at minimum). Currently 14 of 29 files have
  it — that gap is tracked in `tasks/todo.md`.
- Destructive operations require `SupportsShouldProcess` and a documented `-WhatIf` path.

## Out of scope

- **Not a distributable module.** No `.psd1` manifests, no PSGallery publishing, no semantic
  versioning. Don't propose adding them.
- **Not a home for real projects.** When something here grows past a few hundred lines and
  develops its own structure, it graduates to its own repo. This has already happened twice —
  see `decisions.md`. Don't rebuild an extracted project in here.
- **No CI beyond the label-gated parse check.** No test matrix, no scheduled runs, no release
  automation. Why CI was added at all: `decisions.md`, 2026-09-29.
- Cross-platform support. Windows-only, permanently.

## Repository etiquette

- `main` changes only by merging a PR with **Rebase and merge**. Work on `<type>/<issue>-<slug>` — `gh issue develop <n> --name <branch> --checkout` links the branch to its issue.
- After cloning: `git config core.hooksPath .githooks`. The hooks refuse commits and pushes on `main` and enforce the commit format. Never `--no-verify`.
- Commits: Conventional Commits subject, 72 chars max; a body saying what changed and why; `Refs #n`. No pasted file lists. Autosquash `fixup!` commits before a PR is marked ready.
- PRs follow `.github/pull_request_template.md` and say `Closes #n`.
- CI runs only on PRs labelled `ci`. Label when the diff touches: `powershell/**`, `test/**`.
- Commit as the GitHub noreply address, never a work or personal one.

## Work queue

Work lives in GitHub issues. Startable now:

```bash
gh issue list --search "is:open -is:blocked label:status:ready"
```

Add `label:runner:agent` for what an agent can finish alone. New work is filed with
`project:issues-write`; `tasks/todo.md` holds only session-level notes too small for an issue.
