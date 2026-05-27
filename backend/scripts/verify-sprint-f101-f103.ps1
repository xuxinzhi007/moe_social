# F101 + F103 结构验收（Windows，不依赖 bash）
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host '== verify-sprint-f101-f103 (Windows) =='

$checks = @(
  @{ Path = 'internal/biz/admin/users.go'; Pattern = 'ListUsers' },
  @{ Path = 'internal/biz/admin/achievements.go'; Pattern = 'ListAchievements' },
  @{ Path = 'internal/biz/admin/menus.go'; Pattern = 'ListMenus' },
  @{ Path = 'api/internal/admingw/gateway.go'; Pattern = 'AdminListUsers' },
  @{ Path = 'api/internal/logic/admin/adminlistuserslogic.go'; Pattern = 'AdminGW.AdminListUsers' },
  @{ Path = 'internal/biz/llm/inference.go'; Pattern = 'PostChatCompletion' },
  @{ Path = 'internal/service/llm/app.go'; Pattern = 'PostChatCompletion' },
  @{ Path = 'api/internal/logic/llm/chat_inference_helpers.go'; Pattern = 'LLMApp.PostChatCompletion' }
)

foreach ($c in $checks) {
  $full = Join-Path $Root $c.Path
  if (-not (Test-Path $full)) { throw "missing file: $($c.Path)" }
  $text = Get-Content $full -Raw
  if ($text -notmatch [regex]::Escape($c.Pattern)) { throw "pattern not found in $($c.Path): $($c.Pattern)" }
}

go test ./internal/biz/admin/... ./internal/biz/llm/... -count=1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
go build ./api ./rpc
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'OK: F101 admin + F103 llm inference verified'
exit 0
