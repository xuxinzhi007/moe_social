# F102 Admin write CRUD + LLM memory write (Windows)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host '== verify-sprint-f102-admin-memory (Windows) =='

$checks = @(
  @{ Path = 'internal/biz/admin/users_write.go'; Pattern = 'UpdateUser' },
  @{ Path = 'internal/biz/llm/memory_write.go'; Pattern = 'UpsertUserMemory' },
  @{ Path = 'api/internal/logic/admin/adminupdateuserlogic.go'; Pattern = 'AdminGW.AdminUpdateUser' },
  @{ Path = 'api/internal/logic/user/upsertusermemorylogic.go'; Pattern = 'LLMGW.UpsertUserMemory' },
  @{ Path = 'api/internal/llmgw/gateway.go'; Pattern = 'local.UpsertUserMemory' }
)
foreach ($c in $checks) {
  $full = Join-Path $Root $c.Path
  if (-not (Test-Path $full)) { throw "missing: $($c.Path)" }
  if ((Get-Content $full -Raw) -notmatch [regex]::Escape($c.Pattern)) { throw "pattern missing in $($c.Path)" }
}

go test ./internal/biz/admin/... ./internal/biz/llm/... -count=1
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
go build ./api ./rpc
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'OK: F102 verified'
exit 0
