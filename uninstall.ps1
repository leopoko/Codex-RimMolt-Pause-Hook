param(
    [string]$CodexHome = $(Join-Path $env:USERPROFILE ".codex"),
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

function Remove-StopHook {
    param([string]$HooksJsonPath)

    if (-not (Test-Path -LiteralPath $HooksJsonPath)) {
        return
    }

    $config = ConvertTo-Hashtable ((Get-Content -Raw -LiteralPath $HooksJsonPath) | ConvertFrom-Json)
    if (-not $config.ContainsKey("hooks") -or -not $config["hooks"].ContainsKey("Stop")) {
        return
    }

    $remaining = @()
    foreach ($entry in @($config["hooks"]["Stop"])) {
        $hooks = @()
        foreach ($hook in @($entry["hooks"])) {
            if (-not (($hook["command"] -like "*pause-rimmolt.ps1*") -or ($hook["commandWindows"] -like "*pause-rimmolt.ps1*"))) {
                $hooks += $hook
            }
        }

        if ($hooks.Count -gt 0) {
            $entry["hooks"] = [object[]]$hooks
            $remaining += $entry
        }
    }

    $config["hooks"]["Stop"] = [object[]]$remaining
    $config | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $HooksJsonPath -Encoding UTF8
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Remove-StopHook -HooksJsonPath (Join-Path $repoRoot ".codex\hooks.json")

if (-not $ProjectOnly) {
    Remove-StopHook -HooksJsonPath (Join-Path $CodexHome "hooks.json")
    Write-Host "Removed global Codex hook from $CodexHome\hooks.json"
}

Write-Host "Removed project Codex hook from $repoRoot\.codex\hooks.json"
