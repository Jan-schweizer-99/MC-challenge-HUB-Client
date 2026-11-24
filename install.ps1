# MC-challenge-HUB client installer (see install.txt).
#   install.ps1               Fabric, mods, shaderpack, Iris setting
#   install.ps1 -ShaderOnly   only replaces the shaderpack
param([switch]$ShaderOnly, [string]$Java = '', [string]$McDir = (Join-Path $env:APPDATA '.minecraft'), [switch]$NoPause)
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
)
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

$code = 0
try {
    $jar = Join-Path $McDir 'versions\26.3\26.3.jar'
    if (-not (Test-Path $jar)) { throw 'Minecraft 26.3 not found. Start Minecraft Java 26.3 once in the launcher, close it, then run this again.' }
    $packSrc = Join-Path $here 'shaderpacks\ScopeCrystal'
    if (-not (Test-Path $packSrc)) { throw 'Shaderpack not found. Please extract the whole ZIP first.' }
    New-Item -ItemType Directory -Force $tmp | Out-Null

    # Prepare everything first, so a failed download changes nothing.
    Write-Host 'Building textures from your Minecraft ...'
    Copy-Item -Recurse $packSrc (Join-Path $tmp 'ScopeCrystal')
    & (Join-Path $here 'tools\make-textures.ps1') -Jar $jar -OutDir (Join-Path $tmp 'ScopeCrystal\shaders\textures')
    if (-not $ShaderOnly) {
        $javaExe = Find-Java
        foreach ($m in $mods) { Write-Host "Downloading $($m.file) ..."; Get-Checked $m.url $m.hash (Join-Path $tmp $m.file) }
        Write-Host 'Downloading Fabric installer ...'
        Get-Checked $fabric.url $fabric.hash (Join-Path $tmp 'fabric-installer.jar')
        & $javaExe -jar (Join-Path $tmp 'fabric-installer.jar') client -mcversion 26.3 -loader 0.20.1 -dir $McDir | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Fabric installer failed.' }
    }

    $backup = Join-Path $McDir ('mc-hub-backup\' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'))
    New-Item -ItemType Directory -Force $backup, (Join-Path $McDir 'shaderpacks') | Out-Null
    $pack = Join-Path $McDir 'shaderpacks\ScopeCrystal'
    if (Test-Path $pack) { Move-Item $pack (Join-Path $backup 'ScopeCrystal') }
    Copy-Item -Recurse (Join-Path $tmp 'ScopeCrystal') $pack
    if (-not $ShaderOnly) {
        $modDir = Join-Path $McDir 'mods'
        if (Test-Path $modDir) { Move-Item $modDir (Join-Path $backup 'mods') }
        $cfgDir = Join-Path $McDir 'config'
        New-Item -ItemType Directory -Force $modDir, $cfgDir | Out-Null
        foreach ($m in $mods) { Copy-Item -LiteralPath (Join-Path $tmp $m.file) $modDir }
        $cfg = Join-Path $cfgDir 'iris.properties'
        if (Test-Path $cfg) { Copy-Item $cfg $backup }
        Copy-Item (Join-Path $here 'config\iris.properties') $cfg -Force
    }
    Write-Host ''
    Write-Host "Done. Your previous files are in: $backup" -ForegroundColor Green
    if ($ShaderOnly) { Write-Host 'Start Minecraft to use the new shader.' -ForegroundColor Green }
    else { Write-Host 'Launcher -> profile "fabric-loader-26.3" -> Play.' -ForegroundColor Green }
} catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $code = 1
} finally {
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
if (-not $NoPause) { Read-Host 'Press Enter to close' | Out-Null }
exit $code
