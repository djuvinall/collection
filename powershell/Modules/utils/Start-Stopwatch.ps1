function Start-Stopwatch {
    param(
        [int]$IntervalSeconds = 5,
        [int]$Hours = 0,
        [int]$Minutes = 0,
        [int]$Seconds = 0
    )

    $duration = New-TimeSpan -Hours $Hours -Minutes $Minutes -Seconds $Seconds
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    while ($sw.Elapsed -lt $duration) {
        Write-Host "Elapsed: $($sw.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Green
        Start-Sleep -Seconds $IntervalSeconds
    }

    $sw.Stop()
    Write-Host "Done. Total elapsed: $($sw.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Red
}