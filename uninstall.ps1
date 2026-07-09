param(
    [string]$CodexHome = $(Join-Path $env:USERPROFILE ".codex"),
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

function Remove-PauseHook {
    param(
        [string]$HooksJsonPath,
        [string]$EventName
    )

    if (-not (Test-Path -LiteralPath $HooksJsonPath)) {
        return
    }

    $config = ConvertTo-Hashtable ((Get-Content -Raw -LiteralPath $HooksJsonPath) | ConvertFrom-Json)
    if (-not $config.ContainsKey("hooks") -or -not $config["hooks"].ContainsKey($EventName)) {
        return
    }

    if ($null -eq $config["hooks"][$EventName]) {
        $config["hooks"].Remove($EventName)
        Write-JsonFile -Path $HooksJsonPath -Value $config
        return
    }

    $remaining = @()
    foreach ($entry in @($config["hooks"][$EventName])) {
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
        $config["hooks"][$EventName] = [object[]]$remaining
    }
    else {
        $config["hooks"].Remove($EventName)
    }
    Write-JsonFile -Path $HooksJsonPath -Value $config
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Remove-PauseHook -HooksJsonPath (Join-Path $repoRoot ".codex\hooks.json") -EventName "PreCompact"
Remove-PauseHook -HooksJsonPath (Join-Path $repoRoot ".codex\hooks.json") -EventName "Stop"

if ($Global -and -not $ProjectOnly) {
    Remove-PauseHook -HooksJsonPath (Join-Path $CodexHome "hooks.json") -EventName "PreCompact"
    Remove-PauseHook -HooksJsonPath (Join-Path $CodexHome "hooks.json") -EventName "Stop"
    Write-Host "Removed global Codex hook from $CodexHome\hooks.json"
}

Write-Host "Removed project Codex hook from $repoRoot\.codex\hooks.json"
