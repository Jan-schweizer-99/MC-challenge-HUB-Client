# MC-challenge-HUB client installer (see install.txt).
#   install.ps1               Fabric, mods, shaderpack, Iris setting
#   install.ps1 -ShaderOnly   only replaces the shaderpack and our shader menu mod
#   install.ps1 -VR           second, separate profile with Vivecraft in .minecraft\mc-hub-vr (the normal one stays);
#                             VR runs through OpenComposite straight on the OpenXR runtime (Meta Quest Link), no SteamVR
#   install.ps1 -VR -SteamVR  the same, but through SteamVR
param([switch]$ShaderOnly, [switch]$VR, [switch]$SteamVR, [string]$Java = '', [string]$McDir = (Join-Path $env:APPDATA '.minecraft'), [switch]$NoPause)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$here = $PSScriptRoot
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('mc-hub-' + [guid]::NewGuid().ToString('N'))

# Pinned versions, loaded from their official source and checked (SHA-512 / SHA-256).
$mods = @(
    @{ file = 'fabric-api-0.166.2+26.3.jar'; url = 'https://cdn.modrinth.com/data/P7dR8mSH/versions/Zns5SSRA/fabric-api-0.166.2%2B26.3.jar'; hash = 'fb686a9fa923248328107a12498229d6951e316257f18b7d0e4cbd6885ba447ed50a44076a8a5ba47cfe2043b329db3587ab000aeab1face26b2587a5d4ba6b5' }
    @{ file = 'sodium-fabric-0.9.2+mc26.3.jar'; url = 'https://cdn.modrinth.com/data/AANobbMI/versions/bAZQdGpg/sodium-fabric-0.9.2%2Bmc26.3.jar'; hash = 'f3f260f204b8ce5e8777c2c73f537956755ec61f3817b0b78b5e5568e8aa40f14891f146475075109747665c7c88a45ca0ca9a8df3c68d79c58ecdaa8d8c4b93' }
    @{ file = 'iris-fabric-1.11.7+mc26.3.jar'; url = 'https://cdn.modrinth.com/data/YL57xq9U/versions/vTN4NRGW/iris-fabric-1.11.7%2Bmc26.3.jar'; hash = 'd8d3312f77fc52a48e4a6cd836fda33669bdebcb4de0b8c0d30adc808b287330a533e0baef355cc1ce6336a26851d9775369a802a4666b7b7a6266af20088f42' }
    @{ file = 'Gamma-Utils-Fabric-3.2.2+mc26.3.jar'; url = 'https://cdn.modrinth.com/data/wdLuzzEP/versions/k6ywOirE/Gamma-Utils-Fabric-3.2.2%2Bmc26.3.jar'; hash = '6cc6029537b7741af1c7b36a9f44e22bf379c4851c4d44918acc24d2d74009d4739eb1a1296078ac2b8d3d9430083b9452a168059d3ca090394656adbad02575' }
    @{ file = 'cloth-config-fabric-26.3.159.jar'; url = 'https://cdn.modrinth.com/data/9s6osm5g/versions/fg2uyxOW/cloth-config-fabric-26.3.159.jar'; hash = '8924e19d41845096724fa10f3717bc51964a0edbbbcad0ff1e6c6187a398b08f356e49579a657c2dc44a7f92e3850771f3ca70bf8c1f654de60425163b91dbb1' }
)
# VR only: Vivecraft (needs SteamVR; Quest via Link, Air Link or Virtual Desktop)
$vivecraft = @{ file = 'vivecraft-26.3-1.3.18-fabric.jar'; url = 'https://cdn.modrinth.com/data/wGoQDPN5/versions/eV5kQTVM/vivecraft-26.3-1.3.18-fabric.jar'; hash = 'f952c991d2a3a1b63c2746408e6a056b3db108e6f2cde33e2466d6228212bb9fbc667abaedce31943dcc0b7f04d1fe8e060fc8f32b92e34337a7c1fe33e8e761' }
if ($VR) { $mods += $vivecraft }
# VR without SteamVR: OpenComposite answers Vivecraft's OpenVR calls and forwards them to the OpenXR runtime.
# Only for this profile (LWJGL loads this openvr_api.dll), the system and other SteamVR games stay as they are.
# Fixed build of the openxr branch (commit a27e7e6, 2025-05-30), https://gitlab.com/znixian/OpenOVR, GPLv3.
$openComposite = @{ file = 'openvr_api.dll'; url = 'https://opencomposite.znix.xyz/builds/download_build?commit=a27e7e6a64bdcd1eff6b7fba1ea2ea34bcf1273d&build_id=52366409&artefact_id=JjRFMXaxas695QK-'; hash = '3ef564d69b5af1e9ff6bc0d4d55aa32334636a70e084e9c51103953d366e0d13d9871f809e4342c64381de0494b018cd51c43837c37a2837ed6577ced6f19db1' }
$useOpenXR = $VR -and -not $SteamVR
$fabric = @{ url = 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.1.2/fabric-installer-1.1.2.jar'; hash = '61e035bf7bf70153e127440ce34de47c9036f0a2d0c65d1529454bd35ceefe4f' }

function Get-Checked([string]$url, [string]$hash, [string]$out) {
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $out
    $alg = 'SHA256'; if ($hash.Length -eq 128) { $alg = 'SHA512' }
    if ((Get-FileHash -LiteralPath $out -Algorithm $alg).Hash -ne $hash) { throw "Checksum mismatch: $url" }
}
function Find-Java {
    if ($Java) { if (Test-Path $Java) { return $Java }; throw "Java not found: $Java" }
    $roots = @("$env:LOCALAPPDATA\Packages\Microsoft.4297127D64EC6_*\LocalCache\Local\runtime", "$McDir\runtime",
        "$env:APPDATA\.minecraft\runtime", "${env:ProgramFiles(x86)}\Minecraft Launcher\runtime")
    foreach ($r in $roots) {
        $j = Get-ChildItem "$r\*\windows-*\*\bin\java.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($j) { return $j.FullName }
    }
    $cmd = Get-Command java -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw 'No Java found. Run Minecraft 26.3 once, or use: install.ps1 -Java "C:\path\to\java.exe"'
}

# Own game folder for VR: mods, settings and shader apart from the normal profile
$GameDir = if ($VR) { Join-Path $McDir 'mc-hub-vr' } else { $McDir }

$code = 0
try {
    $jar = Join-Path $McDir 'versions\26.3\26.3.jar'
    if (-not (Test-Path $jar)) { throw 'Minecraft 26.3 not found. Start Minecraft Java 26.3 once in the launcher, close it, then run this again.' }
    $packSrc = Join-Path $here 'shaderpacks\ScopeCrystal'
    if (-not (Test-Path $packSrc)) { throw 'Shaderpack not found. Please extract the whole ZIP first.' }
    # Our own mod: shader button in the pause menu (needs Iris and Fabric API).
    $menu = Get-ChildItem (Join-Path $here 'clientmod') -Filter 'shadermenu-*.jar' | Select-Object -First 1
    if (-not $menu) { throw 'Shader menu mod not found. Please extract the whole ZIP first.' }
    $modDir = Join-Path $GameDir 'mods'
    foreach ($f in @(Get-ChildItem $modDir -Filter 'shadermenu-*.jar' -ErrorAction SilentlyContinue)) {
        try { [IO.File]::Open($f.FullName, 'Open', 'ReadWrite', 'None').Close() } catch { throw 'Minecraft is still running. Close it, then run this again.' }
    }
    New-Item -ItemType Directory -Force $tmp | Out-Null

    # Prepare everything first, so a failed download changes nothing.
    Write-Host 'Building textures from your Minecraft ...'
    Copy-Item -Recurse $packSrc (Join-Path $tmp 'ScopeCrystal')
    & (Join-Path $here 'tools\make-textures.ps1') -Jar $jar -OutDir (Join-Path $tmp 'ScopeCrystal\shaders\textures')
    if (-not $ShaderOnly) {
        $javaExe = Find-Java
        foreach ($m in $mods) { Write-Host "Downloading $($m.file) ..."; Get-Checked $m.url $m.hash (Join-Path $tmp $m.file) }
        if ($useOpenXR) {
            Write-Host 'Downloading OpenComposite (VR without SteamVR) ...'
            New-Item -ItemType Directory -Force (Join-Path $tmp 'opencomposite') | Out-Null
            Get-Checked $openComposite.url $openComposite.hash (Join-Path $tmp 'opencomposite\openvr_api.dll')
        }
        Write-Host 'Downloading Fabric installer ...'
        Get-Checked $fabric.url $fabric.hash (Join-Path $tmp 'fabric-installer.jar')
        # Both launcher variants may be installed; Fabric wants each one named.
        $launchers = @()
        if (Test-Path (Join-Path $McDir 'launcher_profiles.json')) { $launchers += 'win32' }
        if (Test-Path (Join-Path $McDir 'launcher_profiles_microsoft_store.json')) { $launchers += 'microsoft_store' }
        if (-not $launchers) { throw 'Minecraft launcher not found. Start it once, close it, then run this again.' }
        foreach ($l in $launchers) {
            & $javaExe -jar (Join-Path $tmp 'fabric-installer.jar') client -mcversion 26.3 -loader 0.20.1 -launcher $l -dir $McDir | Out-Host
            if ($LASTEXITCODE -ne 0) { throw 'Fabric installer failed.' }
        }
    }

    $backup = Join-Path $GameDir ('mc-hub-backup\' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
    New-Item -ItemType Directory -Force $backup, (Join-Path $GameDir 'shaderpacks') | Out-Null
    $pack = Join-Path $GameDir 'shaderpacks\ScopeCrystal'
    if (Test-Path $pack) { Move-Item $pack (Join-Path $backup 'ScopeCrystal') }
    Copy-Item -Recurse (Join-Path $tmp 'ScopeCrystal') $pack
    if (-not $ShaderOnly) {
        if (Test-Path $modDir) { Move-Item $modDir (Join-Path $backup 'mods') }
        $cfgDir = Join-Path $GameDir 'config'
        New-Item -ItemType Directory -Force $modDir, $cfgDir | Out-Null
        foreach ($m in $mods) { Copy-Item -LiteralPath (Join-Path $tmp $m.file) $modDir }
        Copy-Item -LiteralPath $menu.FullName $modDir
        $cfg = Join-Path $cfgDir 'iris.properties'
        if (Test-Path $cfg) { Copy-Item $cfg $backup }
        Copy-Item (Join-Path $here 'config\iris.properties') $cfg -Force
        $ocDll = ''
        if ($useOpenXR) {
            $ocDir = Join-Path $GameDir 'opencomposite'
            New-Item -ItemType Directory -Force $ocDir | Out-Null
            $ocDll = Join-Path $ocDir 'openvr_api.dll'
            Copy-Item -LiteralPath (Join-Path $tmp 'opencomposite\openvr_api.dll') $ocDll -Force
            # Vivecraft asks for every device property it knows; Quest headsets dislike Vulkan for the OpenXR start
            [IO.File]::WriteAllLines((Join-Path $ocDir 'opencomposite.ini'), [string[]]@('admitUnknownProps=true', 'initUsingVulkan=false'))
        }
        if ($VR) {
            # once: language, keys, sound and the server list of the normal profile
            foreach ($f in 'options.txt', 'servers.dat') {
                $from = Join-Path $McDir $f; $to = Join-Path $GameDir $f
                if ((Test-Path $from) -and -not (Test-Path $to)) { Copy-Item $from $to }
            }
            # ready-made Vivecraft profiles (Esc -> Shader -> VR, key F8); never over the player's own saved ones
            $vrp = Join-Path $cfgDir 'scope_shadermenur-profiles'
            New-Item -ItemType Directory -Force $vrp | Out-Null
            foreach ($f in Get-ChildItem (Join-Path $here 'configr-profiles') -Filter '*.json' -ErrorAction SilentlyContinue) {
                if (-not (Test-Path (Join-Path $vrp $f.Name))) { Copy-Item -LiteralPath $f.FullName $vrp }
            }
            # VR draws every picture twice: the shader starts with the profile PERFORMANCE
            $opts = Join-Path $GameDir 'shaderpacks\ScopeCrystal.txt'
            if (-not (Test-Path $opts)) {
                $line = Get-Content (Join-Path $pack 'shaders\shaders.properties') | Where-Object { $_ -like 'profile.PERFORMANCE=*' } | Select-Object -First 1
                $out = foreach ($o in ($line -replace '^profile\.PERFORMANCE=', '') -split ' ') {
                    if (-not $o) { continue }
                    if ($o -like '!*') { "$($o.Substring(1))=false" } elseif ($o -like '*=*') { $o } else { "$o=true" }
                }
                [IO.File]::WriteAllLines($opts, [string[]]$out)
            }
        }
        # only cosmetic: a problem here must not fail the install
        try { & (Join-Path $here 'tools\set-profile.ps1') -McDir $McDir -Backup $backup -VR:$VR -OpenVRDll $ocDll }
        catch { Write-Host "Note: launcher icon not set ($($_.Exception.Message))" -ForegroundColor Yellow }
    }
    if ($ShaderOnly) {
        if ((Get-ChildItem $modDir -Filter 'iris-*.jar' -ErrorAction SilentlyContinue) -and (Get-ChildItem $modDir -Filter 'fabric-api-*.jar' -ErrorAction SilentlyContinue)) {
            Get-ChildItem $modDir -Filter 'shadermenu-*.jar' | Move-Item -Destination $backup
            Copy-Item -LiteralPath $menu.FullName $modDir
        } else { Write-Host 'Note: shader menu mod skipped (Iris or Fabric API not found in mods).' -ForegroundColor Yellow }
    }
    Write-Host ''
    Write-Host "Done. Your previous files are in: $backup" -ForegroundColor Green
    if ($ShaderOnly) { Write-Host 'Start Minecraft to use the new shader.' -ForegroundColor Green }
    elseif ($VR) {
        if ($useOpenXR) {
            Write-Host 'VR runs without SteamVR. Once: Meta Quest Link app -> Settings -> General ->' -ForegroundColor Green
            Write-Host '"OpenXR Runtime": set Meta Quest Link as active. Connect the Quest (Link cable or Air Link).' -ForegroundColor Green
        } else { Write-Host 'Start SteamVR first (Quest: Link cable, Air Link or Virtual Desktop).' -ForegroundColor Green }
        Write-Host 'Launcher -> profile "MC-challenge-HUB VR" -> Play. The normal profile is unchanged.' -ForegroundColor Green
    }
    else { Write-Host 'Launcher -> profile "MC-challenge-HUB" -> Play.' -ForegroundColor Green }
} catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $code = 1
} finally {
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
if (-not $NoPause) { Read-Host 'Press Enter to close' | Out-Null }
exit $code
