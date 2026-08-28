# Scratchpad

Disposable. Half-formed ideas, exploratory notes, things not yet decided.
Nothing here is a commitment. Clear it when it stops being useful.

---

## Open questions from the 2026-08-09 audit

Not decided, not tracked in `todo.md` — thinking out loud.

- Does `work-in-progress/` want a time limit? Several files have sat there across multiple
  reorganizations. A "graduate it or delete it" pass might be worth more than incrementally
  documenting things that are never going to be finished.

- Is `Modules/` vs `functionSnippets/` a distinction that's still earning its keep? Both hold
  dot-sourceable single-function files. The stated difference is maturity, but
  `Test-IsInteractiveSession.ps1` is finished and documented and still lives in snippets. Possible
  collapse into `Modules/utils/` — or possible that the maturity signal is genuinely useful and
  just needs enforcing.

- PSScriptAnalyzer: worth adding? It would catch the `Add-TrustedSite` missing-CmdletBinding and
  the unapproved-verb / snake_case issues automatically. Cost is a dependency on a PSGallery module
  for a repo that currently has zero dependencies — which is one of its nicer properties. Leaning
  yes as a *local* dev tool, no as a committed requirement.

- `Download-Windows11ISO.ps1` — is this worth fixing at all, or should the Axcient mirror URL just
  be replaced with Microsoft's Fido script / official download flow? The mirror has no hash
  verification and points at 23H2, which is aging.
