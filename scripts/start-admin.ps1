# Moe Admin：moe-social（单进程 Kratos HTTP :8888）+ Deploy Agent + Moe Admin 开发服
# powershell -ExecutionPolicy Bypass -File scripts/start-admin.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Backend = Join-Path $Root "backend"
$MoeAdmin = Join-Path $Root "moe-admin"

Write-Host "== Moe Admin 启动 ==" -ForegroundColor Cyan

function Start-JobWindow {
    param([string]$Title, [string]$WorkDir, [string]$Command)
    Start-Process powershell -ArgumentList @(
        "-NoExit", "-Command",
        "cd '$WorkDir'; Write-Host '[$Title]' -ForegroundColor Green; $Command"
    ) | Out-Null
}

Start-JobWindow "moe-social :8888" $Backend "go run ./cmd/moe-social -f config/config.yaml -migrate"
Start-Sleep -Seconds 2
Start-JobWindow "Deploy Agent :19010" $Backend "go run ./cmd/deploy-agent -f deploy/config.yaml"
Start-JobWindow "Moe Admin :5173" $MoeAdmin "if (-not (Test-Path node_modules)) { npm ci }; npm run dev"

Write-Host ""
Write-Host "管理台: http://127.0.0.1:5173/ops/login" -ForegroundColor Green
Write-Host "Agent:  http://127.0.0.1:19010/ (运维 API)"
Write-Host "仅用户/反馈管理时可只开 moe-social+Vite，不必开 Agent。"
