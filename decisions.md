# Decisions

ADR-lite, newest first. Git history records *what* changed; this records *why*, so settled
questions don't get relitigated.

Entries before 2026-08-09 were reconstructed from commit history during the initial audit. Where
the reasoning is inferred rather than stated in the commit message, it says so.

---

## 2026-10-09 — OllamaChat lands as a module under a new `ai/` domain; graduation deferred to #18

**Context:** `OllamaChat.psm1` (an Ollama REST client) was added from outside the repo. At ~520
lines it is bigger than anything else in `Modules/`, and its natural next step, an automatic
tool-call loop with tests, is the kind of growth that sent PSTriageKit and System-Inventory to
their own repos (2026-03-12).

**Decision:** keep it here for now, as one self-contained `.psm1` under a new
`powershell/Modules/ai/` domain folder. Whether it graduates is decided in #18, before the
tool-call loop (#19) is built. #19 is blocked on #18.

**Rejected — put it under `utils/`.** `utils/` is the established catch-all and already holds
other network-egress code (`Get-MyPublicIP`), so it would have avoided a new folder. It lost
because an Ollama client isn't a system utility, and AI tooling is likely to grow into more files
here.

**Consequence:** `Modules/` now has five domains, and two `.psm1` files with an export contract.
The module's default server is Ollama's own (`127.0.0.1:11434`), not a homelab address. Point it
at a real server with `$env:OLLAMA_HOST`.

---

## 2026-09-29 — Default branch renamed `Version-0.00` → `main`; work moves to issues and PRs

**Context:** every change so far was committed straight to `Version-0.00`, a name that implied a
versioning scheme the repo explicitly doesn't have (see Out of scope in `CLAUDE.md`). Planning lived
in `tasks/todo.md` with no way to link work to the commits that did it.

**Decision:** rename the default branch to `main` (GitHub redirects the old name). `main` changes
only by rebase-merging a PR from a `<type>/<issue>-<slug>` branch; local hooks in `.githooks/`
refuse direct commits and pushes to `main` and enforce Conventional Commits with a body. Work is
tracked as GitHub issues.

**Alternatives:** keep `Version-0.00` (rejected — misleading name, and tooling assumes `main`);
branch protection rulesets instead of hooks (rejected — hooks run before the mistake reaches
GitHub, and work the same on every clone that sets `core.hooksPath`).

**Consequences:** existing clones need `git branch -m Version-0.00 main`, `git fetch --prune`,
`git branch -u origin/main main` and `git remote set-head origin -a` — the hooks read the default
branch from `origin/HEAD`, so skipping the last step leaves them guarding the old name. History was
**not** rewritten: old commit messages stay as they are.

## 2026-09-29 — Label-gated CI added, reversing "No CI"

**Context:** the manual verification gate was documented as a pwsh parse check. Run under Windows
PowerShell 5.1 — the actual baseline — 4 of 29 files fail to parse (two use PS7-only syntax, two
are UTF-8 without a BOM). pwsh 7 accepts all four, so the manual gate as written could never have
caught them.

**Decision:** one workflow, `.github/workflows/ci.yml`, on `windows-latest` with `shell: powershell`
(5.1), parse-checking every `.ps1`/`.psm1`. It runs only on non-draft PRs labelled `ci`, or by
hand; pushes and merges run nothing.

**Alternatives:** keep CI out and fix the manual instruction only (rejected — the manual gate is
the one that already failed silently); an ubuntu runner with pwsh (rejected — it runs the parser
that misses exactly these failures).

**Consequences:** "No CI" in `CLAUDE.md` Out of scope is narrowed to "no CI beyond this check".
Public repo, so Actions minutes are free; the label gate still keeps runs deliberate.

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
