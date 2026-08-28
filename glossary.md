# Glossary

Terms that carry a **narrower or repo-specific meaning** here than they do generally. Standard
PowerShell vocabulary is deliberately left out — this file only earns its place by covering the
words where a reasonable assumption would be wrong.

---

**Blast radius** — the organizing idea behind `ARCHITECTURE.md`. Not how complex a script is, but
what it can do to the machine it runs on. Since nothing in this repo depends on anything else,
this replaces the dependency graph a normal architecture doc would map.

**Tier 0 / 1 / 2 / 3** — the blast-radius scale. Pure (no I/O) → read-only → file-mutating →
system-mutating. **A tier is not a quality rating.** `Play-StarWarsTheme.ps1` is Tier 0 and trivial;
`Disable-NonEssentialService.ps1` is Tier 3 and the best-documented file in the repo. Tier answers
"what happens if this is wrong," nothing else.

**System surface** — the concrete set of things a script touches outside the pipeline: registry
keys, CIM/WMI classes, COM objects, network endpoints, external modules. `docs/arch/` documents
system surface; `README.md` documents behavior. Different questions, different files.

**Catalog** vs **surface map** — `README.md` is the catalog (*what does this script do?*).
`ARCHITECTURE.md` + `docs/arch/` are the surface map (*what does it touch and what breaks?*).
Entries are never copied between them.

---

**Domain folder** — a subdirectory of `powershell/Modules/` grouping functions by subject:
`git/`, `math/`, `strings/`, `utils/`. `utils/` is the catch-all and holds everything with a
system surface.

**Waiting room** — what `powershell/functionSnippets/` is. Not a permanent home. Things sit there
until they're stable and reused enough to justify a spot in a domain folder.

**Graduate** — to move a file to a more permanent location once it meets the bar. WIP → snippets →
`Modules/<domain>/`, or, for something that grows past this repo's scope, out to its own repo
entirely (this has happened twice — see `decisions.md`). The graduation bar out of
`work-in-progress/` is: comment-based help, a `Verb-Noun` filename matching its function, and
`SupportsShouldProcess` if it mutates anything.

**`_draft.` prefix** — filename marker meaning *this is a sketch, not a working function*. Usually
a bare pipeline with no `function` block, no parameters, and no help. Dot-sourcing a `_draft.` file
**executes** it rather than defining anything. Removing the prefix asserts it's been properly
wrapped.

**WIP / `work-in-progress/`** — stronger than the usual sense. Files here are **assumed broken
until proven otherwise**; at least one has confirmed defects and none have been executed under
test. Nothing outside the folder may depend on anything inside it.

---

**Dot-source** — running `. .\File.ps1` to pull a function into the current session without
executing anything else. This is the *only* discovery mechanism for `.ps1` files under `Modules/`,
which is why the one-function-per-file / filename-equals-function-name rule is load-bearing rather
than cosmetic.

**`.ps1` vs `.psm1`** — the extension is a contract here, not a preference. `.ps1` = single
function, dot-source it. `.psm1` = a real module with an `Export-ModuleMember` declaration,
`Import-Module` it. Standardizing on `.psm1` was tried in Dec 2025 and reversed in Mar 2026 —
see `decisions.md` before proposing it again.

---

**Scrubbed** — a script derived from real MSP work with all client names, hostnames, internal IP
ranges, tenant IDs, and usernames removed and genericized. The repo is public under The Unlicense,
so scrubbing is the mandatory bar for anything work-derived, not a nicety.

**Friends & Family** — Devon's side IT-support work. Several `utils/` scripts (browser-extension
audit, credential testing, orphaned-installer cleanup) were written for it. Distinct from Kosh
Solutions MSP work, though scripts flow between both.

**ASIO** — ConnectWise ASIO, the RMM platform used at work. `BrowserExtensionsAudit.ps1` emits
structured output shaped for ingestion into it. Explains why that script returns objects rather
than formatted text.

**RSAT** — Remote Server Administration Tools, the optional Windows feature providing the
`ActiveDirectory` and `DhcpServer` PowerShell modules. Two scripts require it and **neither
declares it**, so they fail with a bare "term is not recognized" on a machine without it. Tracked
in `tasks/todo.md`.

**ZoneMap** — the `HKCU:\...\Internet Settings\ZoneMap` registry subtree defining Windows/IE
security zones. `Add-TrustedSite.ps1` writes here. Security-relevant: adding an origin to the
Trusted zone *lowers* policy enforcement for it. HKCU, so no elevation needed — which makes it
easier to run than its blast radius warrants.
