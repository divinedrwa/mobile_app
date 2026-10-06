# Regenerates the Android notification small icon (res/drawable-*/ic_notification.png) from the GatePass+ logo.
#
# Android draws a notification's small icon from its ALPHA CHANNEL ONLY (white shape on a transparent
# background, tinted by the system). A coloured or fully opaque PNG renders as a solid square, which is
# what the old file produced. This turns assets/splash/gp_logo.png into a white "G+" silhouette.
#
# Usage (from mobile_app/):  powershell -ExecutionPolicy Bypass -File scripts/gen-notification-icon.ps1
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$logoPath = Join-Path $root 'assets/splash/gp_logo.png'
$resDir = Join-Path $root 'android/app/src/main/res'

# Density -> px size of the 24dp icon canvas.
$sizes = [ordered]@{ 'mdpi' = 24; 'hdpi' = 36; 'xhdpi' = 48; 'xxhdpi' = 72; 'xxxhdpi' = 96 }
# Share of the canvas the mark may fill (Android guidance: ~22 of 24dp, centred).
$fill = 0.92

$src = [System.Drawing.Bitmap]::FromFile($logoPath)
try {
  # 1. Bounding box of everything visible in the logo.
  $minX = $src.Width; $minY = $src.Height; $maxX = -1; $maxY = -1
  for ($y = 0; $y -lt $src.Height; $y++) {
    for ($x = 0; $x -lt $src.Width; $x++) {
      if ($src.GetPixel($x, $y).A -gt 24) {
        if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }
  if ($maxX -lt 0) { throw 'Logo has no visible pixels.' }
  $cw = $maxX - $minX + 1; $ch = $maxY - $minY + 1; $side = [Math]::Max($cw, $ch)

  # 2. A square white-on-transparent mask of the logo shape, mark centred.
  $mask = New-Object System.Drawing.Bitmap $side, $side, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $offX = [int](($side - $cw) / 2); $offY = [int](($side - $ch) / 2)
  for ($y = 0; $y -lt $ch; $y++) {
    for ($x = 0; $x -lt $cw; $x++) {
      $a = $src.GetPixel($minX + $x, $minY + $y).A
      if ($a -gt 0) { $mask.SetPixel($offX + $x, $offY + $y, [System.Drawing.Color]::FromArgb($a, 255, 255, 255)) }
    }
  }

  # 3. Scale to each density, centred on a transparent canvas.
  foreach ($d in $sizes.Keys) {
    $px = $sizes[$d]
    $target = [int][Math]::Round($px * $fill)
    $out = New-Object System.Drawing.Bitmap $px, $px, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $pos = [int][Math]::Round(($px - $target) / 2)
    $g.DrawImage($mask, $pos, $pos, $target, $target)
    $g.Dispose()
    $dest = Join-Path $resDir "drawable-$d/ic_notification.png"
    $out.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
    Write-Host "wrote $dest (${px}px)"
  }
  $mask.Dispose()
}
finally {
  $src.Dispose()
}
