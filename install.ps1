param(
    [string]$CodexHome = $(Join-Path $env:USERPROFILE ".codex"),
    [string]$McpUrl = "http://localhost:8787/mcp",
    [switch]$Global,
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

function Write-JsonFile {
    param(
        [string]$Path,
        [hashtable]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 20
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8NoBom)
}

function Remove-PauseHookFromEvent {
    param(
        [hashtable]$Config,
        [string]$EventName
    )

    if (-not $Config["hooks"].ContainsKey($EventName)) {
        return
    }

    if ($null -eq $Config["hooks"][$EventName]) {
        $Config["hooks"].Remove($EventName)
        return
    }

    $remaining = @()
    foreach ($entry in @($Config["hooks"][$EventName])) {
        if ($null -eq $entry -or -not $entry.ContainsKey("hooks") -or $null -eq $entry["hooks"]) {
            continue
        }

        $hooks = @()
        foreach ($hook in @($entry["hooks"])) {
            if ($null -eq $hook) {
                continue
            }

            if (-not (($hook["command"] -like "*pause-rimmolt.ps1*") -or ($hook["commandWindows"] -like "*pause-rimmolt.ps1*"))) {
                $hooks += $hook
            }
        }

        if ($hooks.Count -gt 0) {
            $entry["hooks"] = [object[]]$hooks
            $remaining += $entry
        }
    }

    if ($remaining.Count -gt 0) {
        $Config["hooks"][$EventName] = [object[]]$remaining
    }
    else {
        $Config["hooks"].Remove($EventName)
    }
}

function Add-PreCompactHook {
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

    Remove-PauseHookFromEvent -Config $config -EventName "Stop"
    Remove-PauseHookFromEvent -Config $config -EventName "PreCompact"

    $stopEntries = @()
    if ($config["hooks"].ContainsKey("PreCompact") -and $null -ne $config["hooks"]["PreCompact"]) {
        $stopEntries = @($config["hooks"]["PreCompact"])
    }

    $alreadyInstalled = $false
    foreach ($entry in $stopEntries) {
        if ($null -eq $entry -or -not $entry.ContainsKey("hooks") -or $null -eq $entry["hooks"]) {
            continue
        }

        foreach ($hook in @($entry["hooks"])) {
            if ($null -eq $hook) {
                continue
            }

            if (($hook["command"] -like "*pause-rimmolt.ps1*") -or ($hook["commandWindows"] -like "*pause-rimmolt.ps1*")) {
                $hook["command"] = $Command
                $hook["commandWindows"] = $Command
                $hook["timeout"] = 10
                $hook["statusMessage"] = "Pausing RimWorld before compact"
                $entry["matcher"] = "manual|auto"
                $alreadyInstalled = $true
            }
        }
    }

    if (-not $alreadyInstalled) {
        $stopEntries += @{
            matcher = "manual|auto"
            hooks = @(
                @{
                    type = "command"
                    command = $Command
                    commandWindows = $Command
                    timeout = 10
                    statusMessage = "Pausing RimWorld before compact"
                }
            )
        }
    }

    $config["hooks"]["PreCompact"] = [object[]]$stopEntries

    $dir = Split-Path -Parent $HooksJsonPath
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-JsonFile -Path $HooksJsonPath -Value $config
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceHook = Join-Path $repoRoot "hooks\pause-rimmolt.ps1"

if (-not (Test-Path -LiteralPath $sourceHook)) {
    throw "Hook script was not found: $sourceHook"
}

$projectCodexDir = Join-Path $repoRoot ".codex"
$projectHooksPath = Join-Path $projectCodexDir "hooks.json"
$projectCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\hooks\pause-rimmolt.ps1" -Url "{0}" -CodexHook' -f $McpUrl
Add-PreCompactHook -HooksJsonPath $projectHooksPath -Command $projectCommand

if ($Global -and -not $ProjectOnly) {
    $installDir = Join-Path $CodexHome "rimmolt-pause-hook"
    New-Item -ItemType Directory -Force -Path $installDir | Out-Null
    $installedHook = Join-Path $installDir "pause-rimmolt.ps1"
    Copy-Item -LiteralPath $sourceHook -Destination $installedHook -Force

    $userHooksPath = Join-Path $CodexHome "hooks.json"
    $userCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}" -Url "{1}" -CodexHook' -f $installedHook, $McpUrl
    Add-PreCompactHook -HooksJsonPath $userHooksPath -Command $userCommand

    Write-Host "Installed global Codex PreCompact hook:"
    Write-Host "  $userHooksPath"
}

Write-Host "Installed project Codex PreCompact hook:"
Write-Host "  $projectHooksPath"
if (-not $Global) {
    Write-Host ""
    Write-Host "Global Codex hooks were not changed. To install globally, run install.ps1 -Global."
}
Write-Host ""
Write-Host "Restart Codex or start a new Codex session if the hook is not picked up immediately."
