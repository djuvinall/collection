# Get-AvailableWindowsUpdates
# Will retreive available windows updates but you cannot push them with this method.
((New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()).Search("IsInstalled=0").Updates | Format-List Title, IsDownloaded, KBArticleIDs, MsrcSeverity
