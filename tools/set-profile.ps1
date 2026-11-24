# Gives the Fabric profile its own name and icon in the Minecraft launcher.
# Close the launcher first, it overwrites the file on exit.
param([string]$McDir = (Join-Path $env:APPDATA '.minecraft'), [string]$Backup = '')
$ErrorActionPreference = 'Stop'
$icon = 'data:image/png;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'icon.png')))
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
    [IO.File]::WriteAllText($file, ($json | ConvertTo-Json -Depth 50), (New-Object Text.UTF8Encoding($false)))
    $done++
}
if (-not $done) { throw 'Launcher profile "fabric-loader-26.3" not found.' }
