# F104 admin insights 结构验收（Windows）
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host '== verify-sprint-f104-admin-insights (Windows) =='

$checks = @(
  @{ Path = 'internal/biz/admin/insights_ops.go'; Pattern = 'AdminListAiChatSessions' },
  @{ Path = 'api/internal/admingw/gateway.go'; Pattern = 'AdminListAiChatSessions' },
  @{ Path = 'api/internal/logic/admin/admin_insights_logic.go'; Pattern = 'AdminGW.AdminListAiChatSessions' },
  @{ Path = 'api/internal/logic/admin/admin_insights_logic.go'; Pattern = 'AdminGW.AdminAnalyticsOverview' }
)

foreach ($c in $checks) {
  $full = Join-Path $Root $c.Path
  if (-not (Test-Path $full)) { throw "missing file: $($c.Path)" }
  $text = Get-Content $full -Raw
  if ($text -notmatch [regex]::Escape($c.Pattern)) { throw "pattern not found in $($c.Path): $($c.Pattern)" }
}

go build ./api ./rpc
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'OK: F104 admin insights verified'
exit 0
