# Gives the Fabric profile its own name and icon in the Minecraft launcher.
# -VR: a second profile "MC-challenge-HUB VR" with the same Fabric version and its own game folder (mc-hub-vr).
# Close the launcher first, it overwrites the file on exit.
# -OpenVRDll: openvr_api.dll that LWJGL loads for this profile (OpenComposite: VR without SteamVR), empty = SteamVR.
param([string]$McDir = (Join-Path $env:APPDATA '.minecraft'), [string]$Backup = '', [switch]$VR, [string]$OpenVRDll = '')
$ErrorActionPreference = 'Stop'
$icon = 'data:image/png;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $PSScriptRoot $(if ($VR) { 'icon-vr.png' } else { 'icon.png' }))))
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
    if ($VR) {
        $now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        $v = [pscustomobject]@{ name = 'MC-challenge-HUB VR'; type = 'custom'; lastVersionId = $p.lastVersionId; icon = $icon
            gameDir = (Join-Path $McDir 'mc-hub-vr'); created = $now; lastUsed = $now
            javaArgs = $(if ($p.javaArgs) { $p.javaArgs } else { '-Xmx4G -XX:+UseG1GC' }) }
        if ($OpenVRDll) {
            # no quotes (the launcher may pass them on): with spaces in the path, use the short Windows path
            $dll = if ($OpenVRDll -match ' ') { (New-Object -ComObject Scripting.FileSystemObject).GetFile($OpenVRDll).ShortPath } else { $OpenVRDll }
            $v.javaArgs += ' -Dorg.lwjgl.openvr.libname=' + $dll
        }
        $json.profiles | Add-Member -Force -NotePropertyName 'mc-hub-vr' -NotePropertyValue $v
        [IO.File]::WriteAllText($file, ($json | ConvertTo-Json -Depth 50), (New-Object Text.UTF8Encoding($false)))
        $done++
        continue
    }
    $p | Add-Member -Force -NotePropertyName name -NotePropertyValue 'MC-challenge-HUB'
    $p | Add-Member -Force -NotePropertyName icon -NotePropertyValue $icon
    [IO.File]::WriteAllText($file, ($json | ConvertTo-Json -Depth 50), (New-Object Text.UTF8Encoding($false)))
    $done++
}
if (-not $done) { throw 'Launcher profile "fabric-loader-26.3" not found.' }
