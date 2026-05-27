# F108 Admin tail → admingw (Windows)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host '== verify-sprint-f108-admin-tail (Windows) =='

$adminDir = Join-Path $Root 'api/internal/logic/admin'
$hits = Select-String -Path (Join-Path $adminDir '*.go') -Pattern 'SuperRpcClient' -SimpleMatch -ErrorAction SilentlyContinue
if ($hits) {
  throw "SuperRpcClient still in admin logic: $($hits.Count) hits"
}

$checks = @(
  @{ Path = 'internal/biz/admin/moderation_lists.go'; Pattern = 'ListFollows' },
  @{ Path = 'internal/biz/admin/moderation_mutate.go'; Pattern = 'DeletePost' },
  @{ Path = 'internal/biz/admin/accounts.go'; Pattern = 'ListAccounts' },
  @{ Path = 'internal/biz/admin/dashboard.go'; Pattern = 'Dashboard' },
  @{ Path = 'internal/biz/admin/growth_admin.go'; Pattern = 'ListLevelConfigs' },
  @{ Path = 'internal/biz/admin/orders_list.go'; Pattern = 'ListVipOrders' },
  @{ Path = 'api/internal/admingw/gateway.go'; Pattern = 'AdminListFollows' },
  @{ Path = 'api/internal/logic/admin/adminlistfollowslogic.go'; Pattern = 'AdminGW.AdminListFollows' },
  @{ Path = 'api/internal/logic/admin/adminlistaiagentslogic.go'; Pattern = 'AdminGW.AdminListAiAgents' }
)
foreach ($c in $checks) {
  $full = Join-Path $Root $c.Path
  if (-not (Test-Path $full)) { throw "missing: $($c.Path)" }
  if ((Get-Content $full -Raw -Encoding UTF8) -notmatch [regex]::Escape($c.Pattern)) {
    throw "pattern missing in $($c.Path): $($c.Pattern)"
  }
}

go test ./internal/biz/admin/... -count=1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
go build ./api ./rpc
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'OK: F108 admin tail verified'
exit 0
