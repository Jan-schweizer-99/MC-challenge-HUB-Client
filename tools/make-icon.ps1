# Draws icon.png (128x128, 32x32 pixel grid): ice crystal on deep blue. Own artwork.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$px = 4
$bmp = New-Object Drawing.Bitmap 128, 128, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [Drawing.Graphics]::FromImage($bmp)
function Dot([int]$x, [int]$y, [string]$hex) {
    $b = New-Object Drawing.SolidBrush ([Drawing.ColorTranslator]::FromHtml($hex))
    $g.FillRectangle($b, $x * $px, $y * $px, $px, $px); $b.Dispose()
}
# background: blue bands with clipped corners and an ice rim
$bands = '#071A33', '#0B2A4A', '#10365C', '#164572', '#1D5588'
for ($y = 0; $y -lt 32; $y++) { for ($x = 0; $x -lt 32; $x++) {
    $corner = [Math]::Min($x, 31 - $x) + [Math]::Min($y, 31 - $y)
    if ($corner -lt 2) { continue }
    $edge = [Math]::Min([Math]::Min($x, 31 - $x), [Math]::Min($y, 31 - $y))
    if ($edge -eq 0 -or $corner -eq 2) { Dot $x $y '#9FD8FF' }
    elseif ($edge -eq 1 -or $corner -eq 3) { Dot $x $y '#3B86BF' }
    else { Dot $x $y $bands[[Math]::Min(4, [int][Math]::Floor(($x + 31 - $y) / 13))] }
} }
# crystal: cx, top, bottom, half width, shoulder height
function Crystal([int]$cx, [int]$top, [int]$bot, [int]$hw, [string[]]$c) {
    for ($y = $top; $y -le $bot; $y++) {
        $w = [Math]::Min($hw, [Math]::Min($y - $top, $bot - $y))
        for ($dx = -$w; $dx -le $w; $dx++) {
            $x = $cx + $dx
            $col = $c[2]                                             # right facet
            if ($dx -lt 0) { $col = $c[1] }                          # left facet
            if ($dx -eq 0) { $col = $c[0] }                          # ridge
            if ($dx -gt 0 -and ($y - $top) -le $hw) { $col = $c[1] } # tip, right
            if ($dx -lt 0 -and ($y - $top) -le $hw) { $col = $c[0] } # tip, left
            if ([Math]::Abs($dx) -eq $w) { $col = $c[3] }            # outline
            Dot $x $y $col
        }
    }
}
$side = '#BFE9FF', '#5FB8FF', '#2F7FC4', '#0A2440'
$main = '#FFFFFF', '#BFE9FF', '#5FB8FF', '#0A2440'
Crystal 9 12 27 3 $side
Crystal 22 10 27 3 $side
Crystal 16 4 28 5 $main
foreach ($s in @(6, 6), @(25, 5), @(27, 18), @(4, 19)) {
    Dot $s[0] $s[1] '#FFFFFF'
    foreach ($d in @(-1, 0), @(1, 0), @(0, -1), @(0, 1)) { Dot ($s[0] + $d[0]) ($s[1] + $d[1]) '#5FA6D8' }
}
$g.Dispose()
$bmp.Save((Join-Path $PSScriptRoot 'icon.png'), [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
