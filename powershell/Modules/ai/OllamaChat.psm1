#Requires -Version 7.4
using namespace System.Collections
using namespace System.Collections.Generic

<#
    OllamaChat - object-oriented PowerShell client for the Ollama REST API.

    Import-Module .\OllamaChat.psm1
    $chat = New-OllamaSession -Model 'qwen3.5:9b' -System 'Answer tersely.'
    $chat.Send('What is a subnet mask?')
    $chat.Send('And CIDR?')            # same session, history is kept

    Streaming is deliberately not implemented: every call uses stream = false.

    Sessions are independent objects, so any number can be open at once. They also work
    inside ForEach-Object -Parallel / Start-ThreadJob (one session per thread - a single
    session is not safe to call from two threads at the same time).
#>

Set-StrictMode -Version Latest

#region Private

# Normalises an OLLAMA_HOST-style value the way the Ollama CLI reads it:
#   'myhost'          -> http://myhost:11434   (no scheme: http, default port 11434)
#   'myhost:8080'     -> http://myhost:8080
#   'https://myhost'  -> https://myhost        (explicit scheme: that scheme's default port)
#   '0.0.0.0'         -> http://127.0.0.1:11434 (a bind-all server address means "this machine")
function ConvertTo-OllamaServerUri {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Value)

    $value = $Value.Trim()
    $hasScheme = $value -match '^[a-zA-Z][a-zA-Z0-9+.-]*://'
    if (-not $hasScheme) {
        $authority = ($value -split '/', 2)[0]
        # A bare IPv6 address has several colons and no brackets; bracket it so [uri] can parse it.
        if (($authority.Split(':').Count -gt 2) -and -not $authority.StartsWith('[')) {
            $value = $value.Replace($authority, "[$authority]")
            $authority = "[$authority]"
        }
        $hasPort = $authority -match '^\[.+\]:\d+$' -or $authority -match '^[^:\[]+:\d+$'
        $value = "http://$value"
    }

    $builder = [UriBuilder]::new([uri] $value)
    if (-not $hasScheme -and -not $hasPort) { $builder.Port = 11434 }
    if ($builder.Host -eq '0.0.0.0') { $builder.Host = '127.0.0.1' }
    if ($builder.Host -eq '[::]')    { $builder.Host = '[::1]' }
    $builder.Path = ''
    $builder.Uri.GetLeftPart([UriPartial]::Authority)
}

function Invoke-OllamaApi {
    [CmdletBinding()]
    param(
        [ValidateSet('Get', 'Post', 'Delete')]
        [string] $Method = 'Get',

        [Parameter(Mandatory)]
        [string] $Path,

        [IDictionary] $Body,

        [string] $Server = $script:Server,

        [int] $TimeoutSec = 600
    )
    [OllamaSession]::InvokeApi($Method, $Server, $Path, $Body, $TimeoutSec)
}

#endregion

# Default server: $env:OLLAMA_HOST if set (read once, at import), else Ollama's own default.
$script:Server = if ($env:OLLAMA_HOST) {
    ConvertTo-OllamaServerUri -Value $env:OLLAMA_HOST
} else {
    'http://127.0.0.1:11434'
}

#region Class

# NoRunspaceAffinity lets instances be used from other runspaces (ForEach-Object -Parallel,
# Start-ThreadJob). Without it, a method call from another thread deadlocks. For the same
# reason the class calls no module functions - everything it needs is a static method here.
[NoRunspaceAffinity()]
class OllamaSession {
    static [string[]] $Roles = 'system', 'user', 'assistant', 'tool'

    [string]            $Name
    [string]            $Server
    [string]            $Model
    [List[IDictionary]] $Messages = [List[IDictionary]]::new()

    # Request-level keys. $null / empty = omitted from the request (server default applies).
    [hashtable] $Options = @{}     # temperature, top_p, top_k, seed, num_ctx, num_predict, stop, ...
    [object]    $KeepAlive         # '30m', 0 (unload after reply), -1 (keep loaded)
    [object]    $Think             # $true / $false (some models also take 'low' / 'medium' / 'high')
    [object]    $Format            # 'json' or a JSON Schema hashtable
    [object[]]  $Tools             # function definitions for tool calling

    [int]            $TimeoutSec = 600
    [pscustomobject] $LastResponse # full last reply: thinking, tool_calls, token counts, durations

    OllamaSession([string] $Model, [string] $Server) {
        $this.Model  = $Model
        $this.Server = $Server
        $this.Name   = $Model
    }

    # The one place HTTP happens. Ollama returns {"error":"..."} on failure; surface that
    # instead of a bare status code.
    hidden static [object] InvokeApi([string] $Method, [string] $Server, [string] $Path, [IDictionary] $Body, [int] $TimeoutSec) {
        $request = @{
            Method      = $Method
            Uri         = '{0}{1}' -f $Server.TrimEnd('/'), $Path
            TimeoutSec  = $TimeoutSec
            ErrorAction = 'Stop'
        }
        if ($Body) {
            $request.Body        = ConvertTo-Json -InputObject $Body -Depth 32 -Compress
            $request.ContentType = 'application/json; charset=utf-8'
        }

        try {
            return Invoke-RestMethod @request
        }
        catch {
            # Matched by name, not a typed catch: class bodies resolve type literals at parse
            # time, and this type's assembly may not be loaded yet when the module is imported.
            $err = $_
            if ($err.Exception.GetType().Name -ne 'HttpResponseException') { throw }
            $detail = $err.ErrorDetails?.Message
            $reason = try { ($detail | ConvertFrom-Json -ErrorAction Stop).error } catch { $detail }
            if (-not $reason) { $reason = $err.Exception.Message }
            $status = [int] $err.Exception.Response.StatusCode

            # HttpRequestException carries .StatusCode, so callers can branch on 404 vs 500.
            # Resolved by name at runtime for the same parse-time reason as above.
            $exception = ('System.Net.Http.HttpRequestException' -as [type])::new(
                "Ollama $($Method.ToUpper()) $Path failed ($status): $reason",
                $err.Exception,
                [System.Net.HttpStatusCode] $status)
            throw [System.Management.Automation.ErrorRecord]::new(
                $exception, "OllamaApi.$status", [System.Management.Automation.ErrorCategory]::InvalidResult, $Path)
        }
    }

    # File path(s) -> base64 string(s), the format the API expects in "images".
    hidden static [string[]] EncodeImage([string[]] $Path) {
        return [string[]] @(foreach ($p in $Path) {
            $full = (Resolve-Path -LiteralPath $p -ErrorAction Stop).ProviderPath
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($full))
        })
    }

    # Append a message without sending. Returns $this so calls can be chained.
    [OllamaSession] AddMessage([string] $Role, [string] $Content) {
        return $this.AddMessage($Role, $Content, $null, $null)
    }

    [OllamaSession] AddMessage([string] $Role, [string] $Content, [string[]] $ImagePath, [string] $ToolName) {
        if ($Role -notin [OllamaSession]::Roles) {
            throw "Invalid role '$Role'. Valid roles: $([OllamaSession]::Roles -join ', ')."
        }
        $message = [ordered]@{ role = $Role; content = $Content }
        if ($ImagePath) { $message.images    = [OllamaSession]::EncodeImage($ImagePath) }
        if ($ToolName)  { $message.tool_name = $ToolName }
        $this.Messages.Add($message)
        return $this
    }

    hidden [IDictionary] BuildBody() {
        $body = [ordered]@{
            model    = $this.Model
            messages = $this.Messages
            stream   = $false
        }
        if ($this.Options -and $this.Options.Count) { $body.options    = $this.Options }
        if ($null -ne $this.KeepAlive)              { $body.keep_alive = $this.KeepAlive }
        if ($null -ne $this.Think)                  { $body.think      = $this.Think }
        if ($null -ne $this.Format)                 { $body.format     = $this.Format }
        if ($this.Tools)                            { $body.tools      = $this.Tools }
        return $body
    }

    # Send the history as it stands and append the assistant's reply.
    # Call this directly after adding 'tool' results; otherwise use Send().
    [pscustomobject] Complete() {
        $response = [OllamaSession]::InvokeApi('Post', $this.Server, '/api/chat', $this.BuildBody(), $this.TimeoutSec)
        $this.LastResponse = $response

        $reply = [ordered]@{ role = $response.message.role; content = $response.message.content }
        # tool_calls must stay in history for the tool round-trip; thinking is not re-sent.
        if ($response.message.PSObject.Properties['tool_calls']) {
            $reply.tool_calls = $response.message.tool_calls
        }
        $this.Messages.Add($reply)
        return $response
    }

    # Add a user message, send, return the reply text.
    [string] Send([string] $Content) {
        return $this.Send($Content, $null)
    }

    [string] Send([string] $Content, [string[]] $ImagePath) {
        $null = $this.AddMessage('user', $Content, $ImagePath, $null)
        try {
            $response = $this.Complete()
        }
        catch {
            # Roll the user message back so a failed call doesn't pollute history.
            $this.Messages.RemoveAt($this.Messages.Count - 1)
            throw
        }
        # Send() doesn't run tools. Without this, a tool-call reply comes back as '' with no hint.
        if ($response.message.PSObject.Properties['tool_calls']) {
            $names = @($response.message.tool_calls | ForEach-Object { $_.function.name }) -join ', '
            Write-Warning ("Model requested tool call(s): $names. Add each result with " +
                           "Add-OllamaMessage -Role tool, then call .Complete() before sending again.")
        }
        return $response.message.content
    }

    # Clear the conversation but keep system messages.
    [void] Reset() {
        $system = @(foreach ($m in $this.Messages) { if ($m.role -eq 'system') { $m } })
        $this.Messages.Clear()
        foreach ($m in $system) { $this.Messages.Add($m) }
    }

    # Readable view of the conversation. Tool shows calls the model made and which tool a result is for.
    [pscustomobject[]] History() {
        $i = 0
        return @(foreach ($m in $this.Messages) {
            $tool = if ($m.Contains('tool_calls')) {
                'call: ' + (@($m.tool_calls | ForEach-Object {
                    '{0}({1})' -f $_.function.name, (ConvertTo-Json -InputObject $_.function.arguments -Compress -Depth 16)
                }) -join '; ')
            } elseif ($m.Contains('tool_name')) {
                'result: ' + $m.tool_name
            }
            [pscustomobject]@{ Index = $i++; Role = $m.role; Content = $m.content; Tool = $tool }
        })
    }

    [string] ToString() {
        return '{0} [{1}] {2} message(s)' -f $this.Name, $this.Model, $this.Messages.Count
    }
}

#endregion

#region Server

function Get-OllamaServer {
    <#
    .SYNOPSIS
        Returns the default server URL used for new sessions and one-off calls.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $script:Server
}

function Set-OllamaServer {
    <#
    .SYNOPSIS
        Sets the default server URL. Existing sessions keep the server they were created with.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Changes a module variable only; nothing on the system or the server.')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^https?://')]
        [string] $Uri
    )
    $script:Server = $Uri.TrimEnd('/')
}

function Get-OllamaVersion {
    <#
    .SYNOPSIS
        Returns the server version. Doubles as a connectivity check.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string] $Server = $script:Server)
    (Invoke-OllamaApi -Path '/api/version' -Server $Server -TimeoutSec 10).version
}

#endregion

#region Sessions

function New-OllamaSession {
    <#
    .SYNOPSIS
        Creates a chat session object. Each session holds its own history and settings.
    .EXAMPLE
        $chat = New-OllamaSession -Model 'qwen3.5:9b' -System 'Answer tersely.' -Options @{ temperature = 0.2; num_ctx = 8192 }
        $chat.Send('What is a subnet mask?')
    .EXAMPLE
        # Two independent conversations side by side.
        $code = New-OllamaSession -Model 'qwen3-coder:30b' -Name 'code'
        $fast = New-OllamaSession -Model 'llama3.2:3b'     -Name 'fast' -Think $false
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object; no system or server state changes.')]
    [OutputType([OllamaSession])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Model,

        # System prompt, added as the first message.
        [string] $System,

        [string] $Name,

        [hashtable] $Options = @{},

        [object] $KeepAlive,

        [object] $Think,

        [object] $Format,

        [object[]] $Tools,

        [string] $Server = $script:Server,

        [ValidateRange(1, [int]::MaxValue)]
        [int] $TimeoutSec = 600
    )

    $session = [OllamaSession]::new($Model, $Server.TrimEnd('/'))
    $session.Options    = $Options
    $session.TimeoutSec = $TimeoutSec
    if ($Name) { $session.Name = $Name }
    if ($PSBoundParameters.ContainsKey('KeepAlive')) { $session.KeepAlive = $KeepAlive }
    if ($PSBoundParameters.ContainsKey('Think'))     { $session.Think     = $Think }
    if ($PSBoundParameters.ContainsKey('Format'))    { $session.Format    = $Format }
    if ($PSBoundParameters.ContainsKey('Tools'))     { $session.Tools     = $Tools }
    if ($System) { $null = $session.AddMessage('system', $System) }
    $session
}

function Send-OllamaMessage {
    <#
    .SYNOPSIS
        Sends a user message in a session and returns the reply text. Cmdlet form of $session.Send().
    .EXAMPLE
        'Summarise this log' , 'Now list only the errors' | Send-OllamaMessage $chat
    .EXAMPLE
        Send-OllamaMessage $ocr 'Transcribe this.' -ImagePath .\scan.png
    #>
    [CmdletBinding()]
    [OutputType([string], [pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [OllamaSession] $Session,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline)]
        [string] $Content,

        # Image file path(s) for vision models.
        [string[]] $ImagePath,

        # Return the full response object (thinking, tool_calls, timings) instead of the text.
        [switch] $PassThru
    )
    process {
        $text = $Session.Send($Content, $ImagePath)
        if ($PassThru) { $Session.LastResponse } else { $text }
    }
}

function Add-OllamaMessage {
    <#
    .SYNOPSIS
        Appends a message of any role to a session without sending it.
    .DESCRIPTION
        Use to seed history (few-shot examples), add a later system message, or supply a
        'tool' result. After adding tool results, call $session.Complete() to get the reply.
    .EXAMPLE
        Add-OllamaMessage $chat -Role tool -ToolName 'get_weather' -Content '{"temp_f": 61}'
        $chat.Complete().message.content
    #>
    [CmdletBinding()]
    [OutputType([OllamaSession])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [OllamaSession] $Session,

        [Parameter(Mandatory)]
        [ValidateSet('system', 'user', 'assistant', 'tool')]
        [string] $Role,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content,

        [string[]] $ImagePath,

        # Name of the tool whose result this is (role 'tool' only).
        [string] $ToolName,

        [switch] $PassThru
    )
    $null = $Session.AddMessage($Role, $Content, $ImagePath, $ToolName)
    if ($PassThru) { $Session }
}

function Clear-OllamaSession {
    <#
    .SYNOPSIS
        Clears a session's conversation. System messages are kept unless -IncludeSystem is given.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [OllamaSession] $Session,

        [switch] $IncludeSystem
    )
    process {
        if ($IncludeSystem) { $Session.Messages.Clear() } else { $Session.Reset() }
    }
}

#endregion

#region One-off calls

function Invoke-OllamaGenerate {
    <#
    .SYNOPSIS
        Single prompt, no session or history (/api/generate).
    .EXAMPLE
        Invoke-OllamaGenerate -Model 'llama3.2:3b' -Prompt 'One-line definition of DNS.'
    #>
    [CmdletBinding()]
    [OutputType([string], [pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Model,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline)]
        [string] $Prompt,

        [string] $System,

        [string[]] $ImagePath,

        [hashtable] $Options,

        [object] $KeepAlive,

        [object] $Think,

        [object] $Format,

        [string] $Server = $script:Server,

        [int] $TimeoutSec = 600,

        [switch] $PassThru
    )
    process {
        $body = [ordered]@{ model = $Model; prompt = $Prompt; stream = $false }
        if ($System)    { $body.system = $System }
        if ($ImagePath) { $body.images = [OllamaSession]::EncodeImage($ImagePath) }
        if ($Options -and $Options.Count)                { $body.options    = $Options }
        if ($PSBoundParameters.ContainsKey('KeepAlive')) { $body.keep_alive = $KeepAlive }
        if ($PSBoundParameters.ContainsKey('Think'))     { $body.think      = $Think }
        if ($PSBoundParameters.ContainsKey('Format'))    { $body.format     = $Format }

        $response = Invoke-OllamaApi -Method Post -Path '/api/generate' -Body $body -Server $Server -TimeoutSec $TimeoutSec
        if ($PassThru) { $response } else { $response.response }
    }
}

function Get-OllamaEmbedding {
    <#
    .SYNOPSIS
        Returns embedding vector(s) for the input text (/api/embed).
    .EXAMPLE
        $vector = Get-OllamaEmbedding -Model 'nomic-embed-text:latest' -InputText 'hello world'
    .EXAMPLE
        # One request for all three; returns one vector per input, in order.
        'alpha', 'beta', 'gamma' | Get-OllamaEmbedding 'nomic-embed-text:latest'
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Model,

        # Piped strings are collected and sent as one batch request.
        [Parameter(Mandatory, Position = 1, ValueFromPipeline)]
        [string[]] $InputText,

        [hashtable] $Options,

        [object] $KeepAlive,

        [string] $Server = $script:Server,

        [ValidateRange(1, [int]::MaxValue)]
        [int] $TimeoutSec = 600
    )
    begin   { $batch = [List[string]]::new() }
    process { $batch.AddRange($InputText) }
    end {
        $body = [ordered]@{ model = $Model; input = $batch.ToArray() }
        if ($Options -and $Options.Count)                { $body.options    = $Options }
        if ($PSBoundParameters.ContainsKey('KeepAlive')) { $body.keep_alive = $KeepAlive }
        (Invoke-OllamaApi -Method Post -Path '/api/embed' -Body $body -Server $Server -TimeoutSec $TimeoutSec).embeddings
    }
}

#endregion

#region Models

function Get-OllamaModel {
    <#
    .SYNOPSIS
        Lists installed models (/api/tags).
    #>
    [CmdletBinding()]
    param([string] $Server = $script:Server)
    (Invoke-OllamaApi -Path '/api/tags' -Server $Server).models
}

function Get-OllamaRunningModel {
    <#
    .SYNOPSIS
        Lists models currently loaded in memory (/api/ps).
    #>
    [CmdletBinding()]
    param([string] $Server = $script:Server)
    (Invoke-OllamaApi -Path '/api/ps' -Server $Server).models
}

function Get-OllamaModelInfo {
    <#
    .SYNOPSIS
        Returns details for one model: capabilities, parameters, template (/api/show).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string] $Model,

        [string] $Server = $script:Server
    )
    process {
        Invoke-OllamaApi -Method Post -Path '/api/show' -Body @{ model = $Model } -Server $Server
    }
}

function Stop-OllamaModel {
    <#
    .SYNOPSIS
        Unloads a model from memory immediately (keep_alive = 0).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string] $Model,

        [string] $Server = $script:Server
    )
    process {
        if ($PSCmdlet.ShouldProcess($Model, 'Unload from memory')) {
            $null = Invoke-OllamaApi -Method Post -Path '/api/generate' -Body @{ model = $Model; keep_alive = 0 } -Server $Server
        }
    }
}

#endregion

Export-ModuleMember -Function @(
    'Get-OllamaServer', 'Set-OllamaServer', 'Get-OllamaVersion'
    'New-OllamaSession', 'Send-OllamaMessage', 'Add-OllamaMessage', 'Clear-OllamaSession'
    'Invoke-OllamaGenerate', 'Get-OllamaEmbedding'
    'Get-OllamaModel', 'Get-OllamaRunningModel', 'Get-OllamaModelInfo', 'Stop-OllamaModel'
)
