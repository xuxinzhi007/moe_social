# F100-final 结构验收（Windows）：insights + AI + chat + proto SSOT
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host '== verify-sprint-f100-final (Windows) =='

$mustExist = @(
  'internal/biz/admin/insights_ops.go',
  'api/internal/aigw/gateway.go',
  'api/internal/chatgw/gateway.go',
  'api/admin/v1/admin_insights.proto',
  'api/ai/v1/ai_resources.proto',
  'api/llm/v1/llm_chat.proto',
  'api/chat/v1/private_message.proto'
)
foreach ($rel in $mustExist) {
  $full = Join-Path $Root $rel
  if (-not (Test-Path $full)) { throw "missing file: $rel" }
}

$checks = @(
  @{ Path = 'api/internal/logic/admin/admin_insights_logic.go'; Pattern = 'AdminGW.AdminListAiChatSessions' },
  @{ Path = 'api/internal/logic/ai/resource_logic.go'; Pattern = 'AIGW' },
  @{ Path = 'api/internal/logic/chat/chatwslogic.go'; Pattern = 'ChatGW.SendPrivateMessage' },
  @{ Path = 'api/internal/logic/privatemsg/sendprivatemessagelogic.go'; Pattern = 'ChatGW.SendPrivateMessage' },
  @{ Path = 'api/super.api'; Pattern = 'DEPRECATED' },
  @{ Path = 'rpc/super.proto'; Pattern = 'DEPRECATED' }
)

foreach ($c in $checks) {
  $full = Join-Path $Root $c.Path
  if (-not (Test-Path $full)) { throw "missing file: $($c.Path)" }
  $text = Get-Content $full -Raw
  if ($text -notmatch [regex]::Escape($c.Pattern)) { throw "pattern not found in $($c.Path): $($c.Pattern)" }
}

go build ./api ./rpc
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'OK: F100-final structure verified'
exit 0
