# F111 admin audit + user avatar + moe tool local-first (Windows)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host '== verify-sprint-f111 (Windows) =='

$checks = @(
  @{ Path = 'internal/biz/admin/audit_write.go'; Pattern = 'RecordAuditLog' },
  @{ Path = 'internal/biz/user/avatar.go'; Pattern = 'GetUserAvatar' },
  @{ Path = 'api/internal/admingw/gateway_audit.go'; Pattern = 'RecordAdminAuditLog' },
  @{ Path = 'api/internal/common/admin_audit_writer.go'; Pattern = 'AdminGW.RecordAdminAuditLog' },
  @{ Path = 'api/internal/usergw/gateway_f110.go'; Pattern = 'g.local.GetUserAvatar' },
  @{ Path = 'api/internal/moeadmingw/gateway_tools.go'; Pattern = 'g.local.ExecuteTool' },
  @{ Path = 'rpc/internal/logic/getuseravatarlogic.go'; Pattern = 'userbiz.GetUserAvatar' }
)
foreach ($c in $checks) {
  $full = Join-Path $Root $c.Path
  if (-not (Test-Path $full)) { throw "missing: $($c.Path)" }
  if ((Get-Content $full -Raw -Encoding UTF8) -notmatch [regex]::Escape($c.Pattern)) {
    throw "pattern missing in $($c.Path): $($c.Pattern)"
  }
}

$audit = Join-Path $Root 'api/internal/common/admin_audit_writer.go'
if ((Get-Content $audit -Raw) -match 'SuperRpcClient') {
  throw 'admin_audit_writer still uses SuperRpcClient'
}

go test ./internal/biz/user/... ./internal/biz/admin/... -count=1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
go build ./api ./rpc
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'OK: F111 verified'
exit 0
