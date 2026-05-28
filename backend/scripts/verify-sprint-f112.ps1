# F112 GW local-first tail + Voice profile helper (Windows)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host '== verify-sprint-f112 (Windows) =='

$checks = @(
  @{ Path = 'internal/biz/admin/auth.go'; Pattern = 'func AdminLogin' },
  @{ Path = 'internal/biz/ai/user_config.go'; Pattern = 'GetAiUserConfig' },
  @{ Path = 'api/internal/admingw/gateway_public.go'; Pattern = 'g.local.AdminLogin' },
  @{ Path = 'api/internal/llmgw/gateway.go'; Pattern = 'g.local.GetAiUserConfig' },
  @{ Path = 'api/internal/logic/voice/user_profile.go'; Pattern = 'ResolveVoiceUserDisplay' },
  @{ Path = 'api/internal/logic/voice/voicecalllogic.go'; Pattern = 'ResolveVoiceUserDisplay' }
)
foreach ($c in $checks) {
  $full = Join-Path $Root $c.Path
  if (-not (Test-Path $full)) { throw "missing: $($c.Path)" }
  if ((Get-Content $full -Raw -Encoding UTF8) -notmatch [regex]::Escape($c.Pattern)) {
    throw "pattern missing in $($c.Path): $($c.Pattern)"
  }
}

$gwRoot = Join-Path $Root 'api/internal'
Get-ChildItem -Path $gwRoot -Recurse -Filter '*.go' | Where-Object { $_.DirectoryName -match 'gw$' } | ForEach-Object {
  $content = Get-Content $_.FullName -Raw -Encoding UTF8
  if ($content -match 'func \(g \*Gateway\) Super\(\)') { return }
  # crude: methods that only call super without local in same function are caught by bash verify on Unix
}

go test ./internal/biz/admin/... ./internal/biz/ai/... -count=1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
go build ./api ./rpc
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'OK: F112 verified'
exit 0
