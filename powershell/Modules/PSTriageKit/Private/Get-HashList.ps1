function Get-HashList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $items = Get-ChildItem -Path $Root -Recurse -File
    $rootPrefix = (Resolve-Path -Path $Root).Path.TrimEnd('\')
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $lines = foreach ($item in $items) {
        $stream = [System.IO.File]::OpenRead($item.FullName)
        try {
            $hashBytes = $sha.ComputeHash($stream)
        }
        finally { $stream.Dispose() }
        $hash = [BitConverter]::ToString($hashBytes).Replace('-', '')
        $rel = $item.FullName.Substring($rootPrefix.Length).TrimStart('\')
        "$hash *$rel"
    }
    $sha.Dispose()
    return $lines
}
