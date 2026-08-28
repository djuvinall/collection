# Todo

Live working state. Not a handoff document — this file gets edited in place.

Seeded 2026-08-09 from the initial repo audit. Everything below is a real finding from reading the
source, not aspirational cleanup.

## In flight

- [ ] **`git pull` — the local checkout is 1 commit behind `origin/Version-0.00`.** Missing commit
      `681a7fb` "Add HAR to CSV conversion script", which adds `python/convert-har_to_csv.py`.
      **These docs were written against the stale local state and describe no Python at all.**
      After pulling: decide whether `python/` gets a `docs/arch/python.md`, and update
      `CLAUDE.md`'s stack + layout sections. Done = docs match `origin`.
- [ ] Rename `CSS/` → `css/` in git and commit — staged by the audit as a pure rename, needs your
      commit. Fixes the 404 on the README's `css/UserChrome.css` link on GitHub.

## Next

**Correctness — real bugs**

- [ ] **`work-in-progress/Disable-NonEssentialService.ps1` line 1 is corrupt: `11#Requires
      -RunAsAdministrator`.** The stray `11` means PowerShell never parses it as a requirement, so
      **the admin check is not enforced** on the highest-blast-radius script in the repo. Delete
      the two characters. Highest-priority item on this list.
- [ ] Fix the export in `work-in-progress/Get-ComputerCPU.psm1:59` and
      `Get-ComputerMotherboard.psm1:54`. Both call `Export-Module -Function <name>` — not a real
      cmdlet. `Import-Module` on either throws "The term 'Export-Module' is not recognized".
      Should be `Export-ModuleMember`.

- [ ] Fix `Scripts/Download-Windows11ISO.ps1`. Three defects: `$path` doesn't cross into the
      `Start-Job` runspace (needs `$using:path`), it's empty by default anyway, and `Wait-Job`
      with no `Receive-Job` swallows all errors. Done = downloads to a caller-specified path and
      reports failure. Consider moving it to `work-in-progress/` instead if it's not worth fixing.
- [ ] Fix `work-in-progress/fs_tree_scanner.ps1` drive-enumeration block. `Test-Path $drive -eq
      $true` isn't a comparison, `$drive` is a bare letter rather than `"X:\"`, and
      `$drive += $drives` has its operands reversed. Done = `$drives` actually populates.

**Undeclared dependencies**

- [ ] Add `#Requires -Modules ActiveDirectory` to `work-in-progress/user_groups.ps1`.
- [ ] Add `#Requires -Modules DhcpServer` to `functionSnippets/_draft.Get-DHCPReservations.ps1`.
      Both currently fail with a bare "term is not recognized" that doesn't hint at RSAT.
- [ ] Convert `work-in-progress/fs_tree_scanner.ps1`'s PS7 comment into a real `#Requires -Version 7`.

**Safety hardening**

- [ ] Add `[CmdletBinding(SupportsShouldProcess)]` to `Modules/utils/Add-TrustedSite.ps1`. It writes
      IE security-zone policy and currently has no `[CmdletBinding()]` at all — the least-hardened
      Tier-3 function in the repo.
- [ ] Add `SupportsShouldProcess` to `Modules/utils/Set-Theme.ps1` (registry write + explorer restart).
- [ ] Validate `$SetupPath` in `functionSnippets/Start-InteractiveUpgrade.ps1` — it's interpolated
      into a scheduled task running as SYSTEM at highest privilege with no checks. At minimum,
      `Test-Path` and reject user-writable locations.
- [ ] Verify `Disable-NonEssentialService.ps1`'s baseline capture → restore round-trip on a
      disposable VM before it's used anywhere real. Without a captured baseline, disabling is a
      one-way door.

**Documentation**

- [ ] Comment-based help is at 14 of 29 files. Missing on: `Get-CompoundedValue`, `Add-TrustedSite`,
      `Get-DeNestedObject`, `Get-MyPublicIP`, `Start-Stopwatch`, `Download-Windows11ISO`,
      `Play-StarWarsTheme`, `Get-SearchMsUncPath`, `_draft.Get-DHCPReservations`,
      `Get-AvailableWindowsUpdates`, `Get-ComputerCPU`, `Get-ComputerMotherboard`,
      `Get-DisplayMonitor`, `fs_tree_scanner`, `user_groups`. Done = `.SYNOPSIS` minimum on each.
- [ ] Document the RSAT dependencies in `README.md` once the `#Requires` lines are added.

**Housekeeping**

- [ ] `test/` is empty, so git doesn't track it and it doesn't exist on a fresh clone — while
      `README.md` claims it does. Either drop a `.gitkeep` (using this repo's own
      `Add-GitKeep.ps1`) or remove the folder and its README entry.
- [ ] Rename `work-in-progress/user_groups.ps1` → `Get-UserGroups.ps1` to match the repo's
      filename-equals-function-name convention. Same for `fs_tree_scanner.ps1`.
- [ ] Make `Modules/utils/Get-DeNestedObject.ps1` return objects instead of `Write-Host`-ing them.
      Currently returns nothing at all, so its output can't be piped or captured — which defeats
      the point of a flattening helper.
- [ ] Consider merging `Get-ComputerCPU.psm1` + `Get-ComputerMotherboard.psm1` into one
      hardware-inventory module — near-identical structure, and the two most nearly-finished
      files in `work-in-progress/`.

## Blocked

- [ ] Verify whether `git status` is actually clean on your Windows machine — blocked by: needs to
      be run by you. The audit ran git from a Linux sandbox and saw all 29 files as modified with a
      pure CRLF↔LF diff (2494 insertions / 2494 deletions, zero content change). That's most likely
      a sandbox artifact of `core.autocrlf=true`, not a real repo problem. The new `.gitattributes`
      should make this deterministic going forward, but confirm before trusting it.

## Done (recent)

- [x] Initial project context layer: `CLAUDE.md`, `ARCHITECTURE.md`, `docs/arch/`, `tasks/`,
      `decisions.md`, `glossary.md`, `.gitignore`, `.gitattributes` — 2026-08-09
