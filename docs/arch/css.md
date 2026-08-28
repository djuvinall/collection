# css/

**Responsibility:** the one non-PowerShell artifact in the repo — a Firefox `userChrome.css` that
hides the native tab bar. Not a script, not runnable, no blast radius on the OS.

Single file: `css/UserChrome.css`.

## Public interface

Not invoked — installed. Firefox reads it at startup from a fixed location:

```
%APPDATA%\Mozilla\Firefox\Profiles\<profile>\chrome\userChrome.css
```

**The filename must be exactly `userChrome.css`** — lowercase `u`. The file in this repo is named
`UserChrome.css` (capital `U`), so copying it across without renaming works on case-insensitive
Windows but silently does nothing on a case-sensitive filesystem. Rename on install.

## Contract

```css
/* hides the native tabs */
#TabsToolbar {
    visibility: collapse;
}
/* leaves space for the window buttons */
#nav-bar {
    margin-top: 0px;
    margin-right: 0px;
    margin-bottom: 0px;
}
```

Two rules against Firefox's internal chrome DOM:

- `#TabsToolbar` → `visibility: collapse` removes the native tab strip entirely.
- `#nav-bar` → zeroes all margins so the address bar sits flush where the tab strip was.

## Depends on

- **`toolkit.legacyUserProfileCustomizations.stylesheets` must be `true`** in `about:config`.
  Firefox ignores `userChrome.css` entirely without it, with no error and no indication why. This
  is the single most common reason "the CSS doesn't work."
- **Firefox's internal element IDs.** `#TabsToolbar` and `#nav-bar` are unversioned internals, not
  a public API. Mozilla can rename or restructure them in any release. This has been stable for
  years but carries no compatibility guarantee.
- **A vertical-tabs replacement.** Hiding the native tab strip without something else providing tab
  navigation leaves no visible way to switch tabs. This file is meant to accompany a sidebar/
  vertical-tabs setup — either Firefox's built-in vertical tabs or an extension like Sidebery or
  Tree Style Tab.

## Invariants

- **Chrome-only, content-never.** `userChrome.css` styles the browser UI. Styling web page content
  is `userContent.css` and belongs in a separate file if it's ever added.
- **The `#nav-bar` margin rule exists to compensate for the hidden tab strip.** The two rules are
  coupled — removing the `#TabsToolbar` rule without restoring `#nav-bar` margins leaves the window
  controls overlapping the toolbar.
- Zero OS surface. Nothing here touches the registry, filesystem, or network.

## Notes

Requires a Firefox restart to take effect — this is startup-time chrome, not hot-reloaded.

**Case-sensitivity caveat on the folder itself:** git tracked this directory as `CSS/` while
`README.md` links to `css/`. Windows resolves both, but GitHub's web UI does not, so the README
link 404s. Being corrected — see `decisions.md`.
