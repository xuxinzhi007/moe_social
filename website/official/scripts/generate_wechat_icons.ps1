# Generate Moe Social brand icons (WeChat, Flutter source, Android mipmaps).
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File website/official/scripts/generate_wechat_icons.ps1
# Options:
#   -WechatOnly     Only 28x28 and 108x108 for WeChat Open Platform
#   -LetterOnly     Old style: gradient + M letter (no product name)
param(
    [switch]$WechatOnly,
    [switch]$LetterOnly
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$officialDir = Join-Path $PSScriptRoot ".."
$wechatDir = Join-Path $officialDir "wechat-icons"
$brandDir = Join-Path $officialDir "app-icons"
$flutterAsset = Join-Path $repoRoot "assets\branding\app_icon.png"
$androidRes = Join-Path $repoRoot "android\app\src\main\res"

New-Item -ItemType Directory -Force -Path $wechatDir, $brandDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $flutterAsset) | Out-Null

function New-GradientRoundedRect {
    param(
        [System.Drawing.Graphics]$G,
        [System.Drawing.Rectangle]$Rect,
        [int]$Radius
    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($Rect.X, $Rect.Y, $Radius, $Radius, 180, 90)
    $path.AddArc($Rect.Right - $Radius, $Rect.Y, $Radius, $Radius, 270, 90)
    $path.AddArc($Rect.Right - $Radius, $Rect.Bottom - $Radius, $Radius, $Radius, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $Radius, $Radius, $Radius, 90, 90)
    $path.CloseFigure()

    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
        $Rect,
        [System.Drawing.Color]::FromArgb(255, 127, 127, 213),
        [System.Drawing.Color]::FromArgb(255, 145, 234, 228),
        45
    )
    $G.FillPath($brush, $path)
    $brush.Dispose()
    $path.Dispose()
}

function Draw-LetterM {
    param(
        [System.Drawing.Graphics]$G,
        [System.Drawing.Rectangle]$Rect,
        [int]$Size
    )

    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), ([single]([math]::Max(1.5, $Size * 0.09)))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $cx = $Rect.X + $Rect.Width / 2
    $top = $Rect.Y + $Rect.Height * 0.22
    $bottom = $Rect.Y + $Rect.Height * 0.78
    $left = $Rect.X + $Rect.Width * 0.28
    $right = $Rect.Right - $Rect.Width * 0.28
    $midTop = $Rect.Y + $Rect.Height * 0.48

    $G.DrawLine($pen, $left, $bottom, $left, $top)
    $G.DrawLine($pen, $left, $top, $cx, $midTop)
    $G.DrawLine($pen, $cx, $midTop, $right, $top)
    $G.DrawLine($pen, $right, $top, $right, $bottom)
    $pen.Dispose()
}

function Get-FittedFontSize {
    param(
        [System.Drawing.Graphics]$G,
        [string]$Text,
        [single]$MaxWidth,
        [single]$MaxHeight,
        [single]$StartSize,
        [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Bold
    )

    $size = $StartSize
    while ($size -ge 4) {
        $font = New-Object System.Drawing.Font("Segoe UI", $size, $Style)
        $measured = $G.MeasureString($Text, $font)
        $font.Dispose()
        if ($measured.Width -le $MaxWidth -and $measured.Height -le $MaxHeight) {
            return $size
        }
        $size -= 0.5
    }
    return 4
}

function Draw-BrandText {
    param(
        [System.Drawing.Graphics]$G,
        [System.Drawing.Rectangle]$Rect,
        [int]$Size,
        [bool]$ShowSubtitle
    )

    $G.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $padW = [float]$Rect.Width * 0.88
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $sf.Trimming = [System.Drawing.StringTrimming]::None
    $sf.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap

    if ($ShowSubtitle) {
        $titleMaxH = [float]$Rect.Height * 0.42
        $subMaxH = [float]$Rect.Height * 0.24
        $titleSize = Get-FittedFontSize -G $G -Text "Moe" -MaxWidth $padW -MaxHeight $titleMaxH -StartSize ([float]$Size * 0.24)
        $subSize = Get-FittedFontSize -G $G -Text "Social" -MaxWidth $padW -MaxHeight $subMaxH -StartSize ([float]$Size * 0.12) -Style ([System.Drawing.FontStyle]::Regular)

        $titleFont = New-Object System.Drawing.Font("Segoe UI", $titleSize, [System.Drawing.FontStyle]::Bold)
        $subFont = New-Object System.Drawing.Font("Segoe UI", $subSize, [System.Drawing.FontStyle]::Regular)
        $titleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
        $subBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 255, 255, 255))

        $ty = [float]$Rect.Y + ([float]$Rect.Height * 0.24)
        $sy = [float]$Rect.Y + ([float]$Rect.Height * 0.56)
        $titleRect = New-Object System.Drawing.RectangleF ([float]$Rect.X, $ty, [float]$Rect.Width, $titleMaxH)
        $subRect = New-Object System.Drawing.RectangleF ([float]$Rect.X, $sy, [float]$Rect.Width, $subMaxH)

        $G.DrawString("Moe", $titleFont, $titleBrush, $titleRect, $sf)
        $G.DrawString("Social", $subFont, $subBrush, $subRect, $sf)

        $titleFont.Dispose()
        $subFont.Dispose()
        $titleBrush.Dispose()
        $subBrush.Dispose()
    } else {
        $maxH = [float]$Rect.Height * 0.55
        $titleSize = Get-FittedFontSize -G $G -Text "Moe" -MaxWidth $padW -MaxHeight $maxH -StartSize ([float]$Size * 0.28)
        $titleFont = New-Object System.Drawing.Font("Segoe UI", $titleSize, [System.Drawing.FontStyle]::Bold)
        $titleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
        $ty = [float]$Rect.Y + ([float]$Rect.Height * 0.22)
        $titleRect = New-Object System.Drawing.RectangleF ([float]$Rect.X, $ty, [float]$Rect.Width, $maxH)
        $G.DrawString("Moe", $titleFont, $titleBrush, $titleRect, $sf)
        $titleFont.Dispose()
        $titleBrush.Dispose()
    }

    $sf.Dispose()
}

function New-MoeIcon {
    param([int]$Size)

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $margin = [math]::Max(1, [int]($Size * 0.08))
    $rect = New-Object System.Drawing.Rectangle $margin, $margin, ($Size - 2 * $margin), ($Size - 2 * $margin)
    $radius = [math]::Max(2, [int]($Size * 0.22))

    New-GradientRoundedRect -G $g -Rect $rect -Radius $radius

    # WeChat 28/108 and tiny mipmaps: letter M only (text unreadable or clips).
    if ($LetterOnly -or $Size -le 108) {
        Draw-LetterM -G $g -Rect $rect -Size $Size
    } elseif ($Size -lt 256) {
        Draw-BrandText -G $g -Rect $rect -Size $Size -ShowSubtitle:$false
    } else {
        Draw-BrandText -G $g -Rect $rect -Size $Size -ShowSubtitle:$true
    }

    $g.Dispose()
    return $bmp
}

function Save-Icon {
    param([int]$Size, [string]$Path)

    $bmp = New-MoeIcon -Size $Size
    $dir = Split-Path $Path
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    $check = [System.Drawing.Image]::FromFile($Path)
    if ($check.Width -ne $Size -or $check.Height -ne $Size) {
        throw "Wrong size for $Path : $($check.Width)x$($check.Height)"
    }
    $check.Dispose()
    $bytes = (Get-Item $Path).Length
    Write-Host "OK $Path ${Size}x${Size} ($bytes bytes)"
}

function Save-Resized {
    param([string]$SourcePath, [int]$Size, [string]$DestPath)

    $src = [System.Drawing.Image]::FromFile($SourcePath)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($src, 0, 0, $Size, $Size)
    $g.Dispose()
    $src.Dispose()
    $dir = Split-Path $DestPath
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $bmp.Save($DestPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "OK $DestPath ${Size}x${Size}"
}

function Export-WechatIconsFromMaster {
    param([string]$MasterPath)

    if (-not (Test-Path $MasterPath)) {
        throw "Master icon not found: $MasterPath. Run full script first (without -WechatOnly)."
    }

    Write-Host "WeChat icons (scaled from same 1024 as iOS/Android):"
    Write-Host "  Note: iOS AppIcon has 29x29@1x, not 28 — WeChat requires exactly 28x28."
    foreach ($size in @(28, 108)) {
        $path = Join-Path $wechatDir "moe-social-wechat-${size}x${size}.png"
        Save-Resized -SourcePath $MasterPath -Size $size -DestPath $path
        $info = Get-Item $path
        Write-Host "  updated $($info.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    }
}

if ($WechatOnly) {
    $masterCandidate = @(
        $flutterAsset,
        (Join-Path $brandDir "app_icon_1024.png")
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $masterCandidate) {
        throw "No master icon found. Run without -WechatOnly once, or ensure assets/branding/app_icon.png exists."
    }
    Write-Host "WechatOnly: using $masterCandidate"
    Export-WechatIconsFromMaster -MasterPath $masterCandidate
    Write-Host "`nDone. Re-upload wechat-icons/*.png on WeChat Open Platform."
    exit 0
}

Write-Host "Brand assets (master 1024):"
$master = Join-Path $brandDir "app_icon_1024.png"
Save-Icon -Size 1024 -Path $master
foreach ($size in @(512, 256)) {
    Save-Icon -Size $size -Path (Join-Path $brandDir "app_icon_$size.png")
}

Copy-Item -Force $master $flutterAsset
Write-Host "OK copied to $flutterAsset"

Export-WechatIconsFromMaster -MasterPath $master

Write-Host "`nAndroid launcher icons (from 1024 master):"
$androidMap = @{
    "mipmap-mdpi"    = 48
    "mipmap-hdpi"    = 72
    "mipmap-xhdpi"   = 96
    "mipmap-xxhdpi"  = 144
    "mipmap-xxxhdpi" = 192
}
foreach ($folder in $androidMap.Keys) {
    $dest = Join-Path $androidRes "$folder\ic_launcher.png"
    Save-Resized -SourcePath $master -Size $androidMap[$folder] -DestPath $dest
}

Write-Host "`nNext: dart run flutter_launcher_icons"
Write-Host "      (updates ios/Runner/Assets.xcassets/AppIcon.appiconset including 29x29)"
Write-Host "Then: flutter run (or uninstall app first to refresh launcher icon)"
