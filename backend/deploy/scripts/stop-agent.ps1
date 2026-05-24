# 释放 Deploy Agent 端口（Moe 专属 19010，见 docs/dev/ports.md）
$ErrorActionPreference = 'SilentlyContinue'
$ports = @(19010)
$killed = @{}

foreach ($port in $ports) {
  $lines = netstat -ano | Select-String ":$port\s" | Select-String 'LISTENING'
  foreach ($line in $lines) {
    $parts = ($line.Line -replace '\s+', ' ').Trim() -split ' '
    $procId = $parts[-1]
    if ($procId -match '^\d+$' -and -not $killed.ContainsKey($procId)) {
      $killed[$procId] = $true
      Write-Host "Stopping PID $procId (port $port)..."
      Stop-Process -Id ([int]$procId) -Force
    }
  }
}

# go run 临时目录下的 deploy-agent 进程名仍为 deploy-agent
Get-Process -Name 'deploy-agent' -ErrorAction SilentlyContinue | ForEach-Object {
  if (-not $killed.ContainsKey([string]$_.Id)) {
    Write-Host "Stopping deploy-agent PID $($_.Id)..."
    Stop-Process -Id $_.Id -Force
  }
}

Start-Sleep -Milliseconds 500
$still = netstat -ano | Select-String ':19010\s' | Select-String 'LISTENING'
if ($still) {
  Write-Host 'WARN: port 19010 still in use. Close other terminals or run:'
  Write-Host '  Get-NetTCPConnection -LocalPort 19010 | Select OwningProcess'
  exit 1
}
Write-Host 'port 19010 cleared'
exit 0
