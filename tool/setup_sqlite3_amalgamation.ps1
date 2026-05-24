# Download SQLite amalgamation for hooks (avoids GitHub .so download timeout).
# Usage: powershell -ExecutionPolicy Bypass -File tool/setup_sqlite3_amalgamation.ps1
$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
$destDir = Join-Path $root "third_party\sqlite3"
$destC = Join-Path $destDir "sqlite3.c"
$destH = Join-Path $destDir "sqlite3.h"

if ((Test-Path $destC) -and (Test-Path $destH)) {
    Write-Host "sqlite3.c already exists, skip."
    exit 0
}

New-Item -ItemType Directory -Force -Path $destDir | Out-Null
$zipPath = Join-Path $env:TEMP "sqlite-amalgamation.zip"

$urls = @(
    "https://www.sqlite.org/2024/sqlite-amalgamation-3460100.zip",
    "https://sqlite.org/2024/sqlite-amalgamation-3460100.zip"
)

$downloaded = $false
foreach ($url in $urls) {
    try {
        Write-Host "Downloading $url ..."
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -TimeoutSec 120
        $downloaded = $true
        break
    } catch {
        Write-Warning "Failed: $_"
    }
}

if (-not $downloaded) {
    throw "Could not download SQLite amalgamation."
}

Expand-Archive -Path $zipPath -DestinationPath $env:TEMP -Force
$folder = Get-ChildItem -Path $env:TEMP -Directory -Filter "sqlite-amalgamation-*" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $folder) {
    throw "sqlite-amalgamation folder not found after extract."
}

Copy-Item -Force (Join-Path $folder.FullName "sqlite3.c") $destC
Copy-Item -Force (Join-Path $folder.FullName "sqlite3.h") $destH
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

Write-Host "OK: $destC"
Write-Host "OK: $destH"
Write-Host "Next: flutter run"
