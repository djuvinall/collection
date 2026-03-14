#https://www.microsoft.com/software-download/windows11

$path = ""

Start-Job -Name Win11-DL -ScriptBlock { 
    $URL = "https://axcientrestore.blob.core.windows.net/win11/Win11_23H2-x64v2.iso"
    $Path = "C:\$path\Win11_23H2-x64v2.iso"
    Invoke-WebRequest -Uri $URL -OutFile $Path 
}
Wait-Job -Name Win11-DL
