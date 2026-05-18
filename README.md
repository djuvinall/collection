# collection

A personal collection of scripts, modules, and reference material — primarily PowerShell utilities, plus a Firefox `userChrome.css` tweak. Several of the PowerShell utilities double as tooling for Friends & Family IT support work (browser-extension audits, credential testing, orphaned-installer cleanup, etc.).

Released into the public domain under [The Unlicense](LICENSE).

## Repository layout

```
collection/
├── css/                  Firefox UserChrome customization
├── powershell/
│   ├── Modules/          Reusable function libraries (git, math, strings, utils)
│   ├── Scripts/          Standalone scripts
│   ├── functionSnippets/ Reusable snippets & draft functions
│   └── work-in-progress/ Incomplete / experimental
└── test/                 reserved, currently empty
```

## Usage

### Running a script
Invoke directly, or dot-source to pull its functions into the current session:

```powershell
.\Script.ps1                 # run
. .\Script.ps1               # dot-source — exposes any functions defined inside
```

### Importing a module
`.psm1` files are proper PowerShell modules — import them:

```powershell
Import-Module .\SymbolicLinks.psm1
```

Plain `.ps1` files under `Modules/` are single-function files intended to be dot-sourced.

### PowerShell version
Most utilities target **Windows PowerShell 5.1** and will also run on PowerShell 7. Scripts that require PS 7 specifically are flagged in the tables below.

### Admin / registry warning
Several scripts mutate system state and require an elevated session or handle sensitive data. Review before running:

- [`Set-Theme.ps1`](powershell/Modules/utils/Set-Theme.ps1) — writes to the theme registry keys and restarts `explorer.exe`.
- [`Add-TrustedSite.ps1`](powershell/Modules/utils/Add-TrustedSite.ps1) — writes IE security-zone registry entries.
- [`Remove-OrphanedInstallerFile.ps1`](powershell/Modules/utils/Remove-OrphanedInstallerFile.ps1) — deletes files from `C:\Windows\Installer`.
- [`Test-Credential.ps1`](powershell/Modules/utils/Test-Credential.ps1) — handles credentials; treat inputs with care.
- [`SymbolicLinks.psm1`](powershell/Modules/utils/SymbolicLinks.psm1) — requires elevation or Developer Mode to create links.
- [`Start-InteractiveUpgrade.ps1`](powershell/functionSnippets/Start-InteractiveUpgrade.ps1) — registers a scheduled task.

## PowerShell contents

### `powershell/Modules/git/`

| Script | Description |
|---|---|
| [`Add-GitKeep.ps1`](powershell/Modules/git/Add-GitKeep.ps1) | Recursively adds `.gitkeep` files to empty folders so Git will track them. |

### `powershell/Modules/math/`

| Script | Description |
|---|---|
| [`Get-CompoundedValue.ps1`](powershell/Modules/math/Get-CompoundedValue.ps1) | Compound-interest calculator: takes principal, rate, and periods. |

### `powershell/Modules/strings/`

| Script | Description |
|---|---|
| [`Get-UpperCase.ps1`](powershell/Modules/strings/Get-UpperCase.ps1) | Uppercases input strings; pipeline-friendly. |
| [`Invoke-StringScramble.ps1`](powershell/Modules/strings/Invoke-StringScramble.ps1) | Shuffles characters in a string, optionally pinning specified characters in place. |

### `powershell/Modules/utils/`

| Script | Description | Notes |
|---|---|---|
| [`BrowserExtensionsAudit.ps1`](powershell/Modules/utils/BrowserExtensionsAudit.ps1) | Enumerates Chrome and Edge extensions across every local user profile; emits structured output suitable for IT inventory / ConnectWise ASIO. | |
| [`Test-Credential.ps1`](powershell/Modules/utils/Test-Credential.ps1) | Validates credentials against the local machine or Active Directory. | Handles credentials. |
| [`Get-FolderStructure.ps1`](powershell/Modules/utils/Get-FolderStructure.ps1) | Prints an ASCII tree of a directory; optionally includes files. | |
| [`Remove-OrphanedInstallerFile.ps1`](powershell/Modules/utils/Remove-OrphanedInstallerFile.ps1) | Deletes orphaned MSI files from `C:\Windows\Installer` by reconciling against the Installer registry. | Admin; supports `-WhatIf`. |
| [`Set-Theme.ps1`](powershell/Modules/utils/Set-Theme.ps1) | Toggles Windows Light / Dark theme via registry and restarts explorer to apply. | Registry write. |
| [`Get-MyPublicIP.ps1`](powershell/Modules/utils/Get-MyPublicIP.ps1) | Returns the current public IP via ipinfo.io. | |
| [`Add-TrustedSite.ps1`](powershell/Modules/utils/Add-TrustedSite.ps1) | Adds a site or UNC path to a Windows IE security zone (Trusted / Intranet / Internet / Restricted). | Registry write. |
| [`SymbolicLinks.psm1`](powershell/Modules/utils/SymbolicLinks.psm1) | Module for creating, inspecting, and managing Windows symbolic links; includes move-and-replace-with-symlink helpers. | Admin or Developer Mode. |
| [`Get-FileTypeCount.ps1`](powershell/Modules/utils/Get-FileTypeCount.ps1) | Per-extension file statistics for a directory tree: count, total size, average size, date range, percentage of total. | |
| [`Get-DeNestedObject.ps1`](powershell/Modules/utils/Get-DeNestedObject.ps1) | Flattens deeply nested PowerShell objects / JSON structures for inspection and debugging. | |

### `powershell/Scripts/`

| Script | Description | Notes |
|---|---|---|
| [`Download-Windows11ISO.ps1`](powershell/Scripts/Download-Windows11ISO.ps1) | Background-job download of the Windows 11 23H2 x64 ISO. | Set the target path before running. |
| [`Play-StarWarsTheme.ps1`](powershell/Scripts/Play-StarWarsTheme.ps1) | Plays the Star Wars main theme via the console beep API. | For fun. |

### `powershell/functionSnippets/`

| Script | Description | Notes |
|---|---|---|
| [`Test-IsInteractiveSession.ps1`](powershell/functionSnippets/Test-IsInteractiveSession.ps1) | Detects whether PowerShell is running in an interactive user session versus a SYSTEM / service context. | |
| [`Get-SearchMsUncPath.ps1`](powershell/functionSnippets/Get-SearchMsUncPath.ps1) | Extracts UNC paths from Windows `search-ms:` URIs. | |
| [`Start-InteractiveUpgrade.ps1`](powershell/functionSnippets/Start-InteractiveUpgrade.ps1) | Creates a scheduled task to run Windows Setup interactively when invoked from a non-interactive context (RMM, SYSTEM). | Creates scheduled task. |
| [`_draft.Get-DHCPReservations.ps1`](powershell/functionSnippets/_draft.Get-DHCPReservations.ps1) | Retrieves DHCP reservations. | Draft. |

### `powershell/work-in-progress/`

Incomplete or experimental. Treat everything here as unfinished.

| Script | Description |
|---|---|
| [`Get-AvailableWindowsUpdates.ps1`](powershell/work-in-progress/Get-AvailableWindowsUpdates.ps1) | Lists available Windows updates via the `Microsoft.Update.Session` COM object. Read-only — no install capability. |
| [`Get-ComputerCPU.psm1`](powershell/work-in-progress/Get-ComputerCPU.psm1) | Retrieves CPU details (name, manufacturer, cores, speed, socket) via CIM; supports local or remote queries. |
| [`Get-ComputerMotherboard.psm1`](powershell/work-in-progress/Get-ComputerMotherboard.psm1) | Retrieves motherboard details (manufacturer, product, serial, version) via CIM; supports local or remote queries. |
| [`Get-DisplayMonitor.ps1`](powershell/work-in-progress/Get-DisplayMonitor.ps1) | Queries WMI for connected display monitor details (manufacturer, model, serial, manufacturing date). |
| [`fs_tree_scanner.ps1`](powershell/work-in-progress/fs_tree_scanner.ps1) | TreeSize-style directory-size scanner. PowerShell 7. |
| [`user_groups.ps1`](powershell/work-in-progress/user_groups.ps1) | Active Directory group-membership lookup by username or email. |

## CSS

| File | Description |
|---|---|
| [`css/UserChrome.css`](css/UserChrome.css) | Firefox `userChrome.css` that hides the native tab bar and adjusts nav-bar margins. Drop into the Firefox profile's `chrome/` folder and enable `toolkit.legacyUserProfileCustomizations.stylesheets` in `about:config`. |

## Test

Currently empty; reserved for future test files.

## License

Released under [The Unlicense](LICENSE) — public domain, no restrictions.
