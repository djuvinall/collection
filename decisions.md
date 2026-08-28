# Decisions

ADR-lite, newest first. Git history records *what* changed; this records *why*, so settled
questions don't get relitigated.

Entries before 2026-08-09 were reconstructed from commit history during the initial audit. Where
the reasoning is inferred rather than stated in the commit message, it says so.

---

## 2026-08-09 — `ARCHITECTURE.md` organized by blast radius, not by folder contents

**Context:** `README.md` already catalogs every script with a plain-language description. A
conventional `ARCHITECTURE.md` would have restated it and immediately started drifting.

**Decision:** `README.md` owns *"what does this do?"*. `ARCHITECTURE.md` and `docs/arch/` own
*"what does it touch, what does it need, and what breaks?"* — organized by a 4-tier blast-radius
scale (pure / read-only / file-mutating / system-mutating).

**Alternatives:** a per-folder architecture doc mirroring the README (rejected — pure duplication);
a thin `CONVENTIONS.md` with no architecture doc at all (rejected — loses the safety map, which is
the genuinely useful artifact for a repo full of registry writes and COM calls).

**Consequences:** the two documents answer different questions and must be updated for different
reasons. Adding a script updates the README. Changing a script's *system surface* updates
`docs/arch/`. Most changes touch exactly one.

## 2026-08-09 — `CSS/` renamed to `css/`

**Context:** git tracked the directory as `CSS/` while `README.md` linked to `css/UserChrome.css`.
Windows resolves both; GitHub's web UI does not, so the README link 404'd for anyone browsing the
public repo.

**Decision:** rename to lowercase `css/`, matching the all-lowercase convention already used by
`powershell/`.

**Alternatives:** fix the README link to say `CSS/` instead (rejected — inconsistent with the rest
of the tree, and the underlying inconsistency stays).

**Consequences:** requires a two-step `git mv` through a temporary name, because Windows'
case-insensitive filesystem won't perform a case-only rename directly.

## 2026-08-09 — `.gitattributes` pins CRLF for PowerShell files

**Context:** with only `core.autocrlf=true` and no `.gitattributes`, line-ending handling depends
on which platform's git reads the working tree. Reading the repo from a Linux context showed all 29
files as modified with a pure CRLF↔LF diff and zero content change.

**Decision:** `* text=auto`, with `*.ps1` and `*.psm1` pinned to `eol=crlf`.

**Alternatives:** normalize everything to LF (rejected — this is a Windows-only PowerShell repo and
5.1 is happiest with CRLF); do nothing (rejected — leaves the behavior platform-dependent).

**Consequences:** line endings are now determined by the repo rather than by each clone's git
config. A one-time renormalization may show up on the next commit.

---

## 2026-03-13 — Functions grouped into domain folders under `Modules/`

**Context:** `functionSnippets/` had become a flat dumping ground holding everything from string
helpers to registry writers.

**Decision:** split into `Modules/{git,math,strings,utils}/`, keeping `functionSnippets/` as a
waiting room for things not yet stable enough to place. (Commit `962110c`, "more orginization".)

**Alternatives:** not recorded in the commit message. Inferred rationale: flat-folder growth was
making anything hard to find, which cuts directly against the repo's reason to exist.

**Consequences:** adding a function now requires deciding which domain it belongs to, and `utils/`
absorbs anything that doesn't fit cleanly — it's the largest folder by a wide margin. The
`Modules/` vs `functionSnippets/` boundary is maturity-based and is not currently enforced.

## 2026-03-12 — `.psm1` → `.ps1` for single-function files (reversal of a Dec 2025 decision)

**Context:** in December 2025 several single-function files were deliberately renamed *to* `.psm1`
(`Set-Theme`, `Move-SymbolicTarget`, `Start-InteractiveUpgrade`, `Test-IsInteractiveSession`),
apparently to make them importable as modules. This was reversed three months later.

**Decision:** `.ps1` for single-function files meant to be dot-sourced. `.psm1` reserved for files
that are genuinely modules with an `Export-ModuleMember` contract — currently only
`SymbolicLinks.psm1`. (Commit `7af099b`.)

**Alternatives:** the `.psm1`-for-everything approach was the alternative, and it was *tried and
abandoned* — a one-function file gains nothing from `Import-Module` and the extension implied a
module contract that didn't exist.

**Consequences:** the extension now carries meaning. **Don't propose re-standardizing on `.psm1`
— that experiment already ran.** Note that `work-in-progress/Get-ComputerCPU.psm1` and
`Get-ComputerMotherboard.psm1` still carry `.psm1` without export declarations, which is
inconsistent with this decision and is tracked in `tasks/todo.md`.

## 2026-03-12 — Projects that outgrow this repo graduate to their own

**Context:** `PSTriageKit` (a ~45-file module with collectors, private helpers, tests, a manifest,
and a roadmap) and `System-Inventory` had both been developed inside `collection/`, where they
dominated the tree and buried everything else.

**Decision:** remove both; they were rewritten as standalone repos. (Commit `7af099b`, "removed
redundant modules that were rewritten in their own repos.")

**Alternatives:** keeping them here as subdirectories. Rejected implicitly — a repo optimized for
"find and reuse a snippet in under a minute" can't also host multi-file projects with their own
structure and lifecycle.

**Consequences:** this is the standing rule, not a one-off. When something here grows its own
directory structure, manifest, or test suite, it leaves. **Don't rebuild an extracted project
inside `collection/`.** This has now happened twice.

## 2023-03-08 — Repo exists; released under The Unlicense

**Context:** initial commit. A place for code worth referring back to, rather than re-deriving it
each time or losing it in a chat log.

**Decision:** one public repo, no license restrictions (The Unlicense — public domain).

**Consequences:** everything here is public, permanently. That's the reason MSP-derived scripts
must be scrubbed of client names, hostnames, internal ranges, and tenant identifiers before landing
— a constraint recorded in `CLAUDE.md`.
