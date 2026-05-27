# F109 User tail → usergw / llmgw (Windows)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host '== verify-sprint-f109-user-tail (Windows) =='

$userDir = Join-Path $Root 'api/internal/logic/user'
$hits = Select-String -Path (Join-Path $userDir '*.go') -Pattern 'SuperRpcClient' -SimpleMatch -ErrorAction SilentlyContinue
if ($hits) {
  throw "SuperRpcClient still in user logic: $($hits.Count) hits"
}

$checks = @(
  @{ Path = 'internal/biz/user/profile.go'; Pattern = 'UpdateUserInfo' },
  @{ Path = 'internal/biz/user/vip_tail.go'; Pattern = 'CreateVipOrder' },
  @{ Path = 'internal/biz/llm/memory_read.go'; Pattern = 'GetUserMemories' },
  @{ Path = 'api/internal/usergw/gateway_tail.go'; Pattern = 'GetUsers' },
  @{ Path = 'api/internal/llmgw/gateway.go'; Pattern = 'DeleteUserMemory' },
  @{ Path = 'api/internal/logic/user/getuserslogic.go'; Pattern = 'UserGW.GetUsers' }
)
foreach ($c in $checks) {
  $full = Join-Path $Root $c.Path
  if (-not (Test-Path $full)) { throw "missing: $($c.Path)" }
  if ((Get-Content $full -Raw -Encoding UTF8) -notmatch [regex]::Escape($c.Pattern)) {
    throw "pattern missing in $($c.Path): $($c.Pattern)"
  }
}

go test ./internal/biz/user/... ./internal/biz/llm/... -count=1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
go build ./api ./rpc
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'OK: F109 user tail verified'
exit 0
