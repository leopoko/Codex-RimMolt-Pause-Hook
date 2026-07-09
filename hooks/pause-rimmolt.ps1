param(
    [string]$Url = $(if ($env:RIMMOLT_MCP_URL) { $env:RIMMOLT_MCP_URL } else { "http://localhost:8787/mcp" }),
    [int]$TimeoutSeconds = 5,
    [string]$LogFile = $(if ($env:RIMMOLT_HOOK_LOG) { $env:RIMMOLT_HOOK_LOG } else { "" }),
    [switch]$CodexHook,
    [switch]$StrictExit
)

$ErrorActionPreference = "Stop"

function Write-HookLog {
    param([string]$Message)

    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    if (-not $CodexHook) {
        Write-Host $line
    }

    if (-not [string]::IsNullOrWhiteSpace($LogFile)) {
        $dir = Split-Path -Parent $LogFile
        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::AppendAllText($LogFile, $line + [Environment]::NewLine, $utf8NoBom)
    }
}

function Exit-Hook {
    param(
        [int]$Code,
        [string]$Message
    )

    Write-HookLog $Message
    if ($StrictExit) {
        exit $Code
    }
    exit 0
}

try {
    $request = @{
        jsonrpc = "2.0"
        id = 1
        method = "tools/call"
        params = @{
            name = "set_speed"
            arguments = @{
                action = "pause"
            }
        }
    } | ConvertTo-Json -Depth 10 -Compress

    $response = Invoke-RestMethod `
        -UseBasicParsing `
        -Uri $Url `
        -Method Post `
        -ContentType "application/json" `
        -Body $request `
        -TimeoutSec $TimeoutSeconds

    if ($response.error) {
        $message = "RimMolt pause request failed: {0}" -f ($response.error | ConvertTo-Json -Compress -Depth 10)
        Exit-Hook -Code 1 -Message $message
    }

    $text = $null
    if ($response.result -and $response.result.content -and $response.result.content.Count -gt 0) {
        $text = $response.result.content[0].text
    }

    if ([string]::IsNullOrWhiteSpace($text)) {
        Exit-Hook -Code 1 -Message "RimMolt pause request returned an empty response."
    }

    $payload = $text | ConvertFrom-Json
    if ($payload.ok -eq $false) {
        Exit-Hook -Code 0 -Message ("RimMolt did not pause: {0}" -f $payload.message)
    }

    $paused = if ($null -ne $payload.paused) { $payload.paused } else { "unknown" }
    $speed = if ($payload.speed) { $payload.speed } else { "unknown" }
    Exit-Hook -Code 0 -Message ("RimMolt pause sent. paused={0}, speed={1}" -f $paused, $speed)
}
catch {
    Exit-Hook -Code 1 -Message ("RimMolt pause hook error: {0}" -f $_.Exception.Message)
}
