# F110 HTTP zero SuperRpcClient in api/internal/logic (Windows)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host '== verify-sprint-f110 (Windows) =='

$logicRoot = Join-Path $Root 'api/internal/logic'
$hits = Get-ChildItem -Path $logicRoot -Recurse -Filter '*.go' |
  Select-String -Pattern 'SuperRpcClient' -SimpleMatch -ErrorAction SilentlyContinue
if ($hits) {
  throw "SuperRpcClient still in api/internal/logic: $($hits.Count) hits"
}

$checks = @(
  @{ Path = 'api/internal/usergw/gateway_f110.go'; Pattern = 'GetUserAvatar' },
  @{ Path = 'api/internal/admingw/gateway_public.go'; Pattern = 'AdminLogin' },
  @{ Path = 'api/internal/moeadmingw/gateway_tools.go'; Pattern = 'MoeExecuteTool' },
  @{ Path = 'api/internal/llmgw/gateway.go'; Pattern = 'UpsertAiUserConfig' },
  @{ Path = 'api/internal/logic/avatar/getuseravatarlogic.go'; Pattern = 'UserGW.GetUserAvatar' },
  @{ Path = 'api/internal/logic/admin_public/adminloginlogic.go'; Pattern = 'AdminGW.AdminLogin' },
  @{ Path = 'api/internal/logic/moe/executemoetoollogic.go'; Pattern = 'MoeGW.MoeExecuteTool' },
  @{ Path = 'api/internal/logic/chat/private_chat_delivery.go'; Pattern = 'UserGW.CreateNotification' }
)
foreach ($c in $checks) {
  $full = Join-Path $Root $c.Path
  if (-not (Test-Path $full)) { throw "missing: $($c.Path)" }
  if ((Get-Content $full -Raw -Encoding UTF8) -notmatch [regex]::Escape($c.Pattern)) {
    throw "pattern missing in $($c.Path): $($c.Pattern)"
  }
}

go build ./api ./rpc
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'OK: F110 HTTP zero SuperRpc verified'
exit 0
