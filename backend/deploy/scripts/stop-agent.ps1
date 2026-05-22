# 释放本机 9100 端口（Deploy Agent 默认监听）
$seen = @{}
netstat -ano | Select-String ':9100' | Select-String 'LISTENING' | ForEach-Object {
  $procId = ($_.Line.Trim() -split '\s+')[-1]
  if ($procId -match '^\d+$' -and -not $seen.ContainsKey($procId)) {
    $seen[$procId] = $true
    & taskkill /F /PID $procId 2>$null | Out-Null
  }
}
exit 0
