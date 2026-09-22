# Stabilize local Flutter/Android builds on Windows after JVM or IDE crashes.
param(
    [switch]$StopDuplicateLarkMcp
)

$ErrorActionPreference = 'Continue'
$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$android = Join-Path $root 'android'

Write-Host 'Stopping Gradle daemons...'
$gradlew = Join-Path $android 'gradlew.bat'
if (Test-Path -LiteralPath $gradlew) {
    Push-Location $android
    try {
        & $gradlew --stop
    } finally {
        Pop-Location
    }
}

Write-Host 'Stopping stale Flutter tooling daemons...'
Get-CimInstance Win32_Process -Filter "name='dart.exe'" |
    Where-Object { $_.CommandLine -match 'tooling-daemon|devtools' } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force
        Write-Host "stopped dart $($_.ProcessId)"
    }

if ($StopDuplicateLarkMcp) {
    Write-Host 'Stopping duplicate lark-mcp node processes...'
    Get-CimInstance Win32_Process -Filter "name='node.exe'" |
        Where-Object { $_.CommandLine -match 'lark-mcp' } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force
            Write-Host "stopped lark-mcp node $($_.ProcessId)"
        }
}

Write-Host 'Memory snapshot:'
Get-CimInstance Win32_OperatingSystem |
    Select-Object TotalVisibleMemorySize, FreePhysicalMemory, TotalVirtualMemorySize, FreeVirtualMemory |
    Format-List

Write-Host 'Top private-memory processes:'
Get-Process |
    Sort-Object PrivateMemorySize64 -Descending |
    Select-Object -First 15 Id, ProcessName,
        @{Name = 'PrivateMB'; Expression = { [math]::Round($_.PrivateMemorySize64 / 1MB, 1) } },
        @{Name = 'WorkingMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 1) } },
        CPU |
    Format-Table -AutoSize
