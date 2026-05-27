# 释放 make moe-social / make dev 占用的开发端口（Windows）
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File deploy/scripts/stop-moe-social.ps1
$ErrorActionPreference = 'SilentlyContinue'

$ports = @(8080, 8888, 19010, 19011, 19012)
$killed = @{}

function Stop-PortListeners {
  param([int]$Port)
  $lines = netstat -ano | Select-String ":$Port\s" | Select-String 'LISTENING'
  foreach ($line in $lines) {
    $parts = ($line.Line -replace '\s+', ' ').Trim() -split ' '
    $procId = $parts[-1]
    if ($procId -match '^\d+$' -and $procId -ne '0' -and -not $killed.ContainsKey($procId)) {
      $killed[$procId] = $true
      Write-Host "Stopping PID $procId (port $Port)..."
      Stop-Process -Id ([int]$procId) -Force -ErrorAction SilentlyContinue
    }
  }
}

foreach ($port in $ports) {
  Stop-PortListeners -Port $port
}

foreach ($name in @('moe-deploy-agent', 'deploy-agent')) {
  Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
    if (-not $killed.ContainsKey([string]$_.Id)) {
      $killed[$_.Id] = $true
      Write-Host "Stopping $name PID $($_.Id)..."
      Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
  }
}

Start-Sleep -Milliseconds 500

$still = @()
foreach ($port in $ports) {
  $busy = netstat -ano | Select-String ":$port\s" | Select-String 'LISTENING'
  if ($busy) { $still += $port }
}

if ($still.Count -gt 0) {
  Write-Host "WARN: ports still in use: $($still -join ', ')"
  Write-Host 'Try: Get-NetTCPConnection -LocalPort 8080 | Select OwningProcess'
  exit 1
}

Write-Host 'moe-social dev ports cleared (8080, 8888, 19010, 19011, 19012)'
exit 0
