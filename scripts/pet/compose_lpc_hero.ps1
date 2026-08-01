# 从 Universal LPC 仓库按 z 序叠层，生成小家用的 hero_walk / hero_idle。
# 用法：
#   $env:LPC_ROOT = "C:\path\Universal-LPC-Spritesheet-Character-Generator-master"
#   .\scripts\pet\compose_lpc_hero.ps1
#
# 缺脸 = 漏 head + face 层；本脚本默认含 Human Male + Neutral。

param(
  [string]$LpcRoot = $env:LPC_ROOT,
  [string]$OutDir = (Join-Path $PSScriptRoot "..\..\assets\pet\lpc")
)

if (-not $LpcRoot) {
  $LpcRoot = "C:\Users\ZhuanZ1\Downloads\Universal-LPC-Spritesheet-Character-Generator-master"
}
$base = Join-Path $LpcRoot "spritesheets"
if (-not (Test-Path $base)) {
  Write-Error "spritesheets not found under: $LpcRoot"
  exit 1
}

Add-Type -AssemblyName System.Drawing

function Compose-Lpc([string[]]$layers, [string]$outPath) {
  $first = [System.Drawing.Bitmap]::FromFile($layers[0])
  $bmp = New-Object System.Drawing.Bitmap $first.Width, $first.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::Transparent)
  foreach ($layer in $layers) {
    if (-not (Test-Path $layer)) {
      Write-Warning "missing layer: $layer"
      continue
    }
    $img = [System.Drawing.Bitmap]::FromFile($layer)
    $g.DrawImage($img, 0, 0, $bmp.Width, $bmp.Height)
    $img.Dispose()
  }
  $g.Dispose()
  $dir = Split-Path $outPath
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Host "wrote $outPath ($($bmp.Width)x$($bmp.Height))"
  $bmp.Dispose()
  $first.Dispose()
}

$walk = @(
  "$base\body\bodies\male\walk.png",
  "$base\legs\pants\male\walk\teal.png",
  "$base\torso\clothes\longsleeve\longsleeve\male\walk.png",
  "$base\feet\shoes\basic\male\walk\brown.png",
  "$base\head\heads\human\male\walk.png",
  "$base\head\faces\male\neutral\walk.png",
  "$base\hair\afro\adult\walk.png"
)
$idle = @(
  "$base\body\bodies\male\idle.png",
  "$base\legs\pants\male\idle\teal.png",
  "$base\torso\clothes\longsleeve\longsleeve\male\idle.png",
  "$base\feet\shoes\basic\male\idle\brown.png",
  "$base\head\heads\human\male\idle.png",
  "$base\head\faces\male\neutral\idle.png",
  "$base\hair\afro\adult\idle.png"
)

$outDir = (Resolve-Path $OutDir -ErrorAction SilentlyContinue)
if (-not $outDir) { $outDir = Join-Path (Get-Location) "assets\pet\lpc" }

Compose-Lpc $walk (Join-Path $outDir "hero_walk.png")
Compose-Lpc $idle (Join-Path $outDir "hero_idle.png")

Write-Host "Done. Hot-restart Flutter app to reload sheets."
