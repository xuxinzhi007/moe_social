# 释放 Deploy Agent 端口（Moe 专属 19010，见 docs/dev/ports.md）
$ports = @(19010)
$seen = @{}
foreach ($port in $ports) {
  netstat -ano | Select-String ":$port" | Select-String 'LISTENING' | ForEach-Object {
    $procId = ($_.Line.Trim() -split '\s+')[-1]
    if ($procId -match '^\d+$' -and -not $seen.ContainsKey($procId)) {
      $seen[$procId] = $true
      & taskkill /F /PID $procId 2>$null | Out-Null
    }
  }
}
exit 0
