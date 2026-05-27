# F107 私信读路径 + Voice UserGW（Windows）
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host '== verify-sprint-f107-chat-read (Windows) =='

$checks = @(
  @{ Path = 'internal/biz/chat/private_message_read.go'; Pattern = 'ListPrivateMessages' },
  @{ Path = 'api/internal/chatgw/gateway.go'; Pattern = 'ListPrivateConversations' },
  @{ Path = 'api/internal/logic/privatemsg/listprivatemessageslogic.go'; Pattern = 'ChatGW.ListPrivateMessages' },
  @{ Path = 'api/internal/logic/privatemsg/listprivateconversationslogic.go'; Pattern = 'ChatGW.ListPrivateConversations' },
  @{ Path = 'api/internal/logic/voice/voicecalllogic.go'; Pattern = 'UserGW.GetUser' },
  @{ Path = 'docs/dev/voice-ws-boundary.md'; Pattern = 'voicegw' }
)
foreach ($c in $checks) {
  if ($c.Path -like 'docs/*') {
    $full = Join-Path (Split-Path -Parent $Root) $c.Path
  } else {
    $full = Join-Path $Root $c.Path
  }
  if (-not (Test-Path $full)) { throw "missing: $($c.Path)" }
  if ((Get-Content $full -Raw) -notmatch [regex]::Escape($c.Pattern)) { throw "pattern missing in $($c.Path)" }
}

go test ./internal/biz/chat/... -count=1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
go build ./api ./rpc
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'OK: F107 verified'
exit 0
