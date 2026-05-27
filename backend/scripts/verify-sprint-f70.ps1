# PowerShell 版 Sprint F70 验收（Windows 无 bash 时用）
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "== verify-sprint-f70 (powershell) =="

function Assert-File($path) {
    if (-not (Test-Path $path)) { throw "missing file: $path" }
}

function Assert-Grep($pattern, $path) {
    if (-not (Select-String -Path $path -Pattern $pattern -Quiet)) {
        throw "grep failed: $pattern in $path"
    }
}

# S1
Assert-File "internal/service/landing/app.go"
Assert-Grep "LandingGW" "api/internal/svc/servicecontext.go"

# S2
Assert-File "internal/biz/user/vip_orders.go"
Assert-Grep "UserGW.GetVipOrders" "api/internal/logic/user/getviporderslogic.go"

# S3
Assert-File "internal/biz/admin/insights.go"
Assert-Grep "AdminGW.AdminGetGrowthStats" "api/internal/logic/admin/admingetgrowthstatslogic.go"

# S4
Assert-File "api/internal/behaviorgw/gateway.go"
Assert-Grep "BehaviorGW.TrackUserBehaviorEvents" "api/internal/logic/behavior/trackuserbehavioreventslogic.go"

# S5
Assert-File "internal/biz/notify/admin.go"
Assert-Grep "AdminGW.AdminBroadcastNotification" "api/internal/logic/admin/adminbroadcastnotificationlogic.go"

go build ./cmd/moe-social
if ($LASTEXITCODE -ne 0) { throw "go build failed" }

Write-Host "OK: Sprint F70 (powershell smoke)"
