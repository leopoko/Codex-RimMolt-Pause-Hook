param(
    [string]$Version = "dev",
    [string]$OutputDir = "dist"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$resolvedOutputDir = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
}
else {
    Join-Path $repoRoot $OutputDir
}

$packageName = "Codex-RimMolt-Pause-Hook-$Version"
$stagingDir = Join-Path $resolvedOutputDir $packageName
$zipPath = Join-Path $resolvedOutputDir "$packageName.zip"
$checksumPath = Join-Path $resolvedOutputDir "SHA256SUMS.txt"

if (Test-Path -LiteralPath $stagingDir) {
    Remove-Item -LiteralPath $stagingDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $stagingDir | Out-Null

$items = @(
    "README.md",
    "LICENSE",
    "install.ps1",
    "uninstall.ps1",
    "hooks",
    ".codex"
)

foreach ($item in $items) {
    $source = Join-Path $repoRoot $item
    $destination = Join-Path $stagingDir $item

    if (-not (Test-Path -LiteralPath $source)) {
        throw "Release source item was not found: $source"
    }

    if ((Get-Item -LiteralPath $source).PSIsContainer) {
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
    else {
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($stagingDir, $zipPath)

$hash = Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
"$($hash.Hash.ToLowerInvariant())  $(Split-Path -Leaf $zipPath)" | Set-Content -LiteralPath $checksumPath -Encoding UTF8

Write-Host "Created $zipPath"
Write-Host "Created $checksumPath"
