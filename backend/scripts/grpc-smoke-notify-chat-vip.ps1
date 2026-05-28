# P5 域 gRPC 冒烟：notify / chat / vip（需 RPC 监听 :8080，cwd=backend/）
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$HostAddr = if ($env:GRPC_HOST) { $env:GRPC_HOST } else { "127.0.0.1:8080" }
$UserId = if ($env:SMOKE_USER_ID) { $env:SMOKE_USER_ID } else { "smoke-user-1" }

if (-not (Get-Command grpcurl -ErrorAction SilentlyContinue)) {
    Write-Error "grpcurl not found; install: go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest"
}

function Invoke-Smoke {
    param([string]$Name, [string[]]$GrpcArgs)
    Write-Host "==> $Name"
    & grpcurl -plaintext @GrpcArgs
    if ($LASTEXITCODE -ne 0) { throw "grpcurl failed: $Name" }
}

Invoke-Smoke "notify GetNotifications" @(
    "-import-path", "api", "-proto", "api/notify/v1/notify.proto",
    "-d", "{`"user_id`":`"$UserId`",`"page`":1,`"page_size`":5}",
    $HostAddr, "notify.v1.NotifyService/GetNotifications"
)

Invoke-Smoke "notify GetUnreadCount" @(
    "-import-path", "api", "-proto", "api/notify/v1/notify.proto",
    "-d", "{`"user_id`":`"$UserId`"}",
    $HostAddr, "notify.v1.NotifyService/GetUnreadCount"
)

Invoke-Smoke "chat ListPrivateConversations" @(
    "-import-path", "api", "-proto", "api/chat/v1/private_message.proto",
    "-d", "{`"user_id`":`"$UserId`",`"limit`":10,`"offset`":0}",
    $HostAddr, "chat.v1.PrivateMessageService/ListPrivateConversations"
)

Invoke-Smoke "vip GetVipRecords" @(
    "-import-path", "api", "-proto", "api/vip/v1/vip.proto",
    "-d", "{`"user_id`":`"$UserId`",`"page`":1,`"page_size`":5}",
    $HostAddr, "vip.v1.VipService/GetVipRecords"
)

Invoke-Smoke "vip GetUserActiveVipRecord" @(
    "-import-path", "api", "-proto", "api/vip/v1/vip.proto",
    "-d", "{`"user_id`":`"$UserId`"}",
    $HostAddr, "vip.v1.VipService/GetUserActiveVipRecord"
)

Write-Host "OK: grpc smoke notify/chat/vip @ $HostAddr"
