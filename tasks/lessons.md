# Lessons

Things learned the hard way. One entry per lesson. Always include the *why* — a lesson without its
reasoning gets overruled by the next plausible-sounding idea.

Seeded 2026-08-09 from the initial audit. These three are derived from defects found in the source,
so they're real mistakes that were actually made here, not generic PowerShell advice.

## 2026-08-09 — A `#Requires` statement is silently ignored unless it starts its line

**What happened:** `work-in-progress/Disable-NonEssentialService.ps1` line 1 is
`11#Requires -RunAsAdministrator` — two stray characters, almost certainly a paste accident. The
script's admin requirement has never been enforced, and it reads as correctly guarded to anyone
skimming it.

**Why:** `#Requires` is handled by the parser, not the runtime, and only when it's the first
non-whitespace token on a line. With `11` in front, PowerShell sees the numeric literal `11`
followed by an ordinary comment. No error, no warning — the statement just does nothing.

**Do instead:** treat `#Requires` as unverifiable by reading. Confirm it works by actually running
the script unelevated and checking that it refuses to start. Applies equally to `-Version` and
`-Modules`. A guard you haven't seen fire is a guard you don't have.

## 2026-08-09 — `Export-Module` is not a cmdlet; `Export-ModuleMember` is

**What happened:** both `Get-ComputerCPU.psm1` and `Get-ComputerMotherboard.psm1` end with
`Export-Module -Function <name>`. Importing either throws "The term 'Export-Module' is not
recognized."

**Why:** the name is plausible enough to autocomplete from memory, and there *is* no
`Export-Module` — the noun is `ModuleMember`. Because the line sits at the bottom of the file, the
functions above it define fine and the error only surfaces at the end of `Import-Module`, which
makes it easy to misread as unrelated noise.

**Do instead:** `Export-ModuleMember -Function <names>`. Verify a `.psm1` by running
`Import-Module .\File.psm1 -Force` and then `Get-Command -Module File` — if the export line is
wrong, the import errors and the module list comes back empty.

## 2026-08-09 — Variables don't cross into `Start-Job` script blocks

**What happened:** `Scripts/Download-Windows11ISO.ps1` sets `$path` in the caller's scope and then
references it inside a `Start-Job -ScriptBlock`. The download silently writes to the wrong location.

**Why:** `Start-Job` runs its script block in a **separate runspace** with its own scope. The
caller's variables simply aren't there — the reference resolves to `$null` and string
interpolation turns it into an empty string. No error, no warning. `Start-ThreadJob`,
`Invoke-Command`, and `ForEach-Object -Parallel` all have the same boundary.

**Do instead:** pass values explicitly with `$using:varname` or `-ArgumentList`. When a job's
behavior depends on outside state, that state has to cross the boundary deliberately.

## 2026-08-09 — `Wait-Job` without `Receive-Job` discards errors

**What happened:** the same script calls `Wait-Job` and then ends. A failed download is
indistinguishable from a successful one.

**Why:** job output — including errors — is buffered in the job object and only surfaces when you
`Receive-Job`. `Wait-Job` blocks until completion and returns the job, not its results. Discarding
that means discarding the error stream.

**Do instead:** always `Receive-Job` after `Wait-Job`, and check `$job.State -eq 'Failed'`. Silence
from a background job is not evidence of success.

## 2026-08-09 — `Test-Path $x -eq $true` is not a comparison

**What happened:** `work-in-progress/fs_tree_scanner.ps1` has `if (Test-Path $drive -eq $true)`.
The loop never populates its accumulator and the scan never runs.

**Why:** PowerShell parses this in *command* mode, not expression mode. `-eq` and `$true` are
handed to `Test-Path` as extra positional arguments rather than forming a comparison. `Test-Path`
returns a boolean anyway, so the `if` "works" — it just isn't testing what it looks like it's
testing.

**Do instead:** `if (Test-Path $drive)`. If a comparison genuinely is needed, parenthesize the
command first: `if ((Test-Path $drive) -eq $true)`. More generally — a cmdlet call inside a
conditional needs its own parentheses before any operator can apply to its result.
