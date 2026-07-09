param(
    [string]$CodexHome = $(Join-Path $env:USERPROFILE ".codex"),
    [string]$McpUrl = "http://localhost:8787/mcp",
    [switch]$ProjectOnly
)

$ErrorActionPreference = "Stop"

function ConvertTo-Hashtable {
    param($InputObject)

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $hash = @{}
        foreach ($key in $InputObject.Keys) {
            $hash[$key] = ConvertTo-Hashtable $InputObject[$key]
        }
        return $hash
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $items = @()
        foreach ($item in $InputObject) {
            $items += ConvertTo-Hashtable $item
        }
        return $items
    }

    if ($InputObject -is [pscustomobject]) {
        $hash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = ConvertTo-Hashtable $property.Value
        }
        return $hash
    }

    return $InputObject
}

function Add-StopHook {
    param(
        [string]$HooksJsonPath,
        [string]$Command
    )

    if (Test-Path -LiteralPath $HooksJsonPath) {
        $raw = Get-Content -Raw -LiteralPath $HooksJsonPath
        if ([string]::IsNullOrWhiteSpace($raw)) {
            $config = @{ hooks = @{} }
        }
        else {
            $config = ConvertTo-Hashtable ($raw | ConvertFrom-Json)
        }
    }
    else {
        $config = @{ hooks = @{} }
    }

    if (-not $config.ContainsKey("hooks") -or $null -eq $config["hooks"]) {
        $config["hooks"] = @{}
    }

    $stopEntries = @()
    if ($config["hooks"].ContainsKey("Stop") -and $null -ne $config["hooks"]["Stop"]) {
        $stopEntries = @($config["hooks"]["Stop"])
    }

    $alreadyInstalled = $false
    foreach ($entry in $stopEntries) {
        foreach ($hook in @($entry["hooks"])) {
            if (($hook["command"] -like "*pause-rimmolt.ps1*") -or ($hook["commandWindows"] -like "*pause-rimmolt.ps1*")) {
                $hook["command"] = $Command
                $hook["commandWindows"] = $Command
                $hook["timeout"] = 10
                $hook["statusMessage"] = "Pausing RimWorld via RimMolt"
                $alreadyInstalled = $true
            }
        }
    }

    if (-not $alreadyInstalled) {
        $stopEntries += @{
            hooks = @(
                @{
                    type = "command"
                    command = $Command
                    commandWindows = $Command
                    timeout = 10
                    statusMessage = "Pausing RimWorld via RimMolt"
                }
            )
        }
    }

    $config["hooks"]["Stop"] = [object[]]$stopEntries

    $dir = Split-Path -Parent $HooksJsonPath
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $HooksJsonPath -Encoding UTF8
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceHook = Join-Path $repoRoot "hooks\pause-rimmolt.ps1"

if (-not (Test-Path -LiteralPath $sourceHook)) {
    throw "Hook script was not found: $sourceHook"
}

$projectCodexDir = Join-Path $repoRoot ".codex"
$projectHooksPath = Join-Path $projectCodexDir "hooks.json"
$projectCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\hooks\pause-rimmolt.ps1" -Url "{0}"' -f $McpUrl
Add-StopHook -HooksJsonPath $projectHooksPath -Command $projectCommand

if (-not $ProjectOnly) {
    $installDir = Join-Path $CodexHome "rimmolt-pause-hook"
    New-Item -ItemType Directory -Force -Path $installDir | Out-Null
    $installedHook = Join-Path $installDir "pause-rimmolt.ps1"
    Copy-Item -LiteralPath $sourceHook -Destination $installedHook -Force

    $userHooksPath = Join-Path $CodexHome "hooks.json"
    $userCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}" -Url "{1}"' -f $installedHook, $McpUrl
    Add-StopHook -HooksJsonPath $userHooksPath -Command $userCommand

    Write-Host "Installed global Codex Stop hook:"
    Write-Host "  $userHooksPath"
}

Write-Host "Installed project Codex Stop hook:"
Write-Host "  $projectHooksPath"
Write-Host ""
Write-Host "Restart Codex or start a new Codex session if the hook is not picked up immediately."
