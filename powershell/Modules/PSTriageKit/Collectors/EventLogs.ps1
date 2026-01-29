[CmdletBinding()]
param(
    [int]$SinceHours = 72
)

function Invoke-Collector {
    [CmdletBinding()]
    param(
        [int]$SinceHours = 72
    )

    $windowStart = (Get-Date).AddHours(-1 * $SinceHours)
    $requestedLogs = @('System','Application','Security')
    $isAdmin = Test-IsAdmin

    $results = @()
    foreach ($log in $requestedLogs) {
        if ($log -eq 'Security' -and -not $isAdmin) {
            $results += [pscustomobject]@{
                LogName          = $log
                Id               = $null
                Level            = $null
                LevelDisplayName = $null
                ProviderName     = $null
                TimeCreated      = $null
                Message          = $null
                SkipReason       = 'Administrator rights required'
            }
            continue
        }

        try {
            $filter = @{ LogName = $log; StartTime = $windowStart; Level = 1,2,3 }
            $events = Get-WinEvent -FilterHashtable $filter -MaxEvents 500 -ErrorAction Stop
            foreach ($event in @($events)) {
                $message = $event.Message
                if ($message -and $message.Length -gt 2000) { $message = $message.Substring(0,2000) }
                $levelName = if ($event.LevelDisplayName) { $event.LevelDisplayName } else { $event.Level }
                $results += [pscustomobject]@{
                    LogName          = $event.LogName
                    Id               = $event.Id
                    Level            = $levelName
                    LevelDisplayName = $levelName
                    ProviderName     = $event.ProviderName
                    TimeCreated      = $event.TimeCreated
                    Message          = $message
                }
            }
            if (-not $events -or @($events).Count -eq 0) {
                $results += [pscustomobject]@{
                    LogName      = $log
                    SkipReason   = 'No events in window'
                    Id           = $null
                    Level        = $null
                    LevelDisplayName = $null
                    ProviderName = $null
                    TimeCreated  = $null
                    Message      = $null
                }
            }
        }
        catch {
            $results += [pscustomobject]@{
                LogName          = $log
                Id               = $null
                Level            = $null
                LevelDisplayName = $null
                ProviderName     = $null
                TimeCreated      = $null
                Message          = $null
                SkipReason       = $_.Exception.Message
            }
        }

        $logEntries = $results | Where-Object { $_.LogName -eq $log }
        if (-not $logEntries -or ($logEntries.Count -eq 0)) {
            $results += [pscustomobject]@{
                LogName          = $log
                Id               = $null
                Level            = $null
                LevelDisplayName = $null
                ProviderName     = $null
                TimeCreated      = $null
                Message          = $null
                SkipReason       = 'No events collected'
            }
        }
    }

    return $results
}

Invoke-Collector -SinceHours $SinceHours
