# 从本地 Universal LPC 仓库导出分层 PNG 到 assets/pet/lpc/layers/
# 管理台改 catalog 后在此目录增删层，再跑本脚本或手动放文件。
param(
  [string]$LpcRoot = $env:LPC_ROOT,
  [string]$OutDir = (Join-Path $PSScriptRoot "..\..\assets\pet\lpc\layers")
)

if (-not $LpcRoot) {
  $LpcRoot = "C:\Users\ZhuanZ1\Downloads\Universal-LPC-Spritesheet-Character-Generator-master"
}
$base = Join-Path $LpcRoot "spritesheets"
if (-not (Test-Path $base)) { Write-Error "spritesheets missing: $LpcRoot"; exit 1 }

Add-Type -AssemblyName System.Drawing

function Export-Layer([string]$src, [string]$name) {
  if (-not (Test-Path $src)) { Write-Warning "skip $name"; return }
  $dir = (Resolve-Path $OutDir -ErrorAction SilentlyContinue)
  if (-not $dir) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null; $dir = Resolve-Path $OutDir }
  $dst = Join-Path $dir "$name.png"
  [System.Drawing.Image]::FromFile($src).Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Host "export $name"
}

$pairs = @{
  "body_walk"       = "$base\body\bodies\male\walk.png"
  "body_idle"       = "$base\body\bodies\male\idle.png"
  "head_walk"       = "$base\head\heads\human\male\walk.png"
  "head_idle"       = "$base\head\heads\human\male\idle.png"
  "face_walk"       = "$base\head\faces\male\neutral\walk.png"
  "face_idle"       = "$base\head\faces\male\neutral\idle.png"
  "hair_walk"       = "$base\hair\afro\adult\walk.png"
  "hair_idle"       = "$base\hair\afro\adult\idle.png"
  "bottom_teal_walk" = "$base\legs\pants\male\walk\teal.png"
  "bottom_teal_idle" = "$base\legs\pants\male\idle\teal.png"
  "top_longsleeve_walk" = "$base\torso\clothes\longsleeve\longsleeve\male\walk.png"
  "top_longsleeve_idle" = "$base\torso\clothes\longsleeve\longsleeve\male\idle.png"
  "shoes_brown_walk" = "$base\feet\shoes\basic\male\walk\brown.png"
  "shoes_brown_idle" = "$base\feet\shoes\basic\male\idle\brown.png"
}

foreach ($kv in $pairs.GetEnumerator()) { Export-Layer $kv.Value $kv.Key }

Write-Host "Done -> $OutDir"
