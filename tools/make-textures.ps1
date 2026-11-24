# Builds the two block-texture atlases from the player's own Minecraft 26.3 jar.
# They contain Mojang textures, so they are generated locally and never published.
param([Parameter(Mandatory)][string]$Jar, [Parameter(Mandatory)][string]$OutDir)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.IO.Compression.FileSystem

function New-Atlas($zip, [string[]]$names, [bool]$keepAlpha, [string]$out) {
    $atlas = New-Object Drawing.Bitmap ($names.Count * 32), 320, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        for ($i = 0; $i -lt $names.Count; $i++) {
            $entry = $zip.GetEntry("assets/minecraft/textures/block/$($names[$i]).png")
            if ($null -eq $entry) { throw "Texture missing in Minecraft jar: $($names[$i])" }
            $stream = $entry.Open()
            $src = New-Object Drawing.Bitmap $stream
            try {
                if ($src.Width -ne 16 -or $src.Height % 16) { throw "Unexpected texture size: $($names[$i])" }
                $frames = [int]($src.Height / 16)
                # only unique frames are computed; the rest repeats
                for ($f = 0; $f -lt [Math]::Min($frames, 20); $f++) {
                    for ($l = 0; $l -le 4; $l++) {
                        $size = 16 -shr $l; $sc = 1 -shl $l; $off = 32 - (32 -shr $l); $n = $sc * $sc
                        for ($y = 0; $y -lt $size; $y++) { for ($x = 0; $x -lt $size; $x++) {
                            $r = 0; $g = 0; $b = 0; $a = 0
                            for ($sy = 0; $sy -lt $sc; $sy++) { for ($sx = 0; $sx -lt $sc; $sx++) {
                                $p = $src.GetPixel($x * $sc + $sx, $f * 16 + $y * $sc + $sy)
                                $r += $p.R; $g += $p.G; $b += $p.B; $a += $p.A
                            } }
                            $al = 255; if ($keepAlpha) { $al = [int]($a / $n) }
                            $c = [Drawing.Color]::FromArgb($al, [int]($r / $n), [int]($g / $n), [int]($b / $n))
                            for ($k = $f; $k -lt 20; $k += $frames) { $atlas.SetPixel($i * 32 + $off + $x, $k * 16 + $y, $c) }
                        } }
                    }
                }
            } finally { $src.Dispose(); $stream.Dispose() }
        }
        $atlas.Save($out, [Drawing.Imaging.ImageFormat]::Png)
    } finally { $atlas.Dispose() }
}

New-Item -ItemType Directory -Force $OutDir | Out-Null
$zip = [IO.Compression.ZipFile]::OpenRead($Jar)
try {
    $mat = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'materials.json') -Raw | ConvertFrom-Json
    $names = @($mat | ForEach-Object { $_.blueTex; $_.lavaTex })
    New-Atlas $zip $names $true (Join-Path $OutDir 'arena-palette.png')
    New-Atlas $zip @('polished_blackstone', 'blackstone', 'magma', 'lava_still') $false (Join-Path $OutDir 'lava-floor.png')
} finally { $zip.Dispose() }
