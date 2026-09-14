Add-Type -AssemblyName System.Drawing

$size = 1024
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$bg = [System.Drawing.Color]::FromArgb(27, 67, 50)
$g.Clear($bg)

$gold = [System.Drawing.Color]::FromArgb(212, 175, 55)
$white = [System.Drawing.Color]::FromArgb(245, 245, 245)

$ballBrush = New-Object System.Drawing.SolidBrush $gold
$ballRect = New-Object System.Drawing.Rectangle 312, 312, 400, 400
$g.FillEllipse($ballBrush, $ballRect)

$stumpBrush = New-Object System.Drawing.SolidBrush $white
$stumpPen = New-Object System.Drawing.Pen $white, 18
$stumpPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$stumpPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

$stumpX = @(430, 512, 594)
foreach ($x in $stumpX) {
    $g.DrawLine($stumpPen, $x, 520, $x, 760)
}
$g.DrawLine($stumpPen, 418, 520, 606, 520)

$outDir = Join-Path $PSScriptRoot "..\assets\images"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outPath = Join-Path $outDir "app_icon.png"
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$bmp.Dispose()

Write-Host "Generated $outPath"
