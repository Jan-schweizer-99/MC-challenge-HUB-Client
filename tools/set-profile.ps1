# Gives the Fabric profile its own name and icon (blue hardcore heart with VR headset) in the Minecraft launcher.
# Removes the separate "MC-challenge-HUB VR" profile of older installs (its folder mc-hub-vr stays).
# Close the launcher first, it overwrites the file on exit.
param([string]$McDir = (Join-Path $env:APPDATA '.minecraft'), [string]$Backup = '')
$ErrorActionPreference = 'Stop'
$icon = 'data:image/png;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'icon-vr.png')))
if (-not $Backup) { $Backup = Join-Path $McDir ('mc-hub-backup\' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')) }
$done = 0
foreach ($name in 'launcher_profiles.json', 'launcher_profiles_microsoft_store.json') {
    $file = Join-Path $McDir $name
    if (-not (Test-Path $file)) { continue }
    $json = [IO.File]::ReadAllText($file) | ConvertFrom-Json
    $p = $json.profiles.'fabric-loader-26.3'
    if ($null -eq $p) { continue }
    New-Item -ItemType Directory -Force $Backup | Out-Null
    Copy-Item $file $Backup
    $p | Add-Member -Force -NotePropertyName name -NotePropertyValue 'MC-challenge-HUB'
    $p | Add-Member -Force -NotePropertyName icon -NotePropertyValue $icon
    # older installs: the OpenVR library came from here, now the menu mod sets it (and the VR profile is gone)
    if ($p.javaArgs -match 'openvr\.libname') { $p.javaArgs = ($p.javaArgs -replace '\s*-Dorg\.lwjgl\.openvr\.libname=\S+', '').Trim() }
    if ($json.profiles.PSObject.Properties['mc-hub-vr']) { $json.profiles.PSObject.Properties.Remove('mc-hub-vr') }
    [IO.File]::WriteAllText($file, ($json | ConvertTo-Json -Depth 50), (New-Object Text.UTF8Encoding($false)))
    $done++
}
if (-not $done) { throw 'Launcher profile "fabric-loader-26.3" not found.' }
