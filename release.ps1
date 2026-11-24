# Builds both ZIPs from the committed state; -Publish pushes and creates the GitHub release.
#   .\release.ps1 1.0.1 "What changed" -Publish
param([Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version, [string]$Notes = 'Shader update', [switch]$Publish)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
[IO.Directory]::SetCurrentDirectory($PSScriptRoot)
$repo = 'Jan-schweizer-99/MC-challenge-HUB-Client'
function Assert-Ok([string]$what) { if ($LASTEXITCODE -ne 0) { throw "$what failed" } }
if (git status --porcelain) { throw 'Uncommitted changes - commit first.' }

# Only our own files may be published.
$files = @(git ls-files)
$bad = @($files | Where-Object { $_ -match '\.(jar|class|key|secret|bak|zip)$|arena-palette\.png|lava-floor\.png|server\.properties|rcon|\.panel-key' })
if ($bad) { throw "Must not be published: $($bad -join ', ')" }
# Compare with the real secret values of the local server (values are never printed).
$vals = @()
foreach ($f in '..\.panel-key', '..\minecraft-server\rcon-password.txt') { if (Test-Path $f) { $vals += (Get-Content $f -Raw).Trim() } }
$sp = '..\minecraft-server\server.properties'
if (Test-Path $sp) { $vals += @(Get-Content $sp | Where-Object { $_ -match '^[\w.-]*(password|secret)=.{6,}' } | ForEach-Object { ($_ -split '=', 2)[1].Trim() }) }
$vals = @($vals | Where-Object { $_ })
$text = ($files | ForEach-Object { [IO.File]::ReadAllText((Join-Path $PSScriptRoot $_)) }) -join "`n"
foreach ($v in $vals) { if ($text.Contains($v)) { throw 'SECRET FOUND in tracked files - aborted.' } }
"Secret check: $($vals.Count) values, 0 hits"

New-Item -ItemType Directory -Force dist | Out-Null
$common = 'install.ps1', 'install.txt', 'tools', 'shaderpacks'
$full = 'dist/MC-challenge-HUB-Client.zip'; $shader = 'dist/ScopeCrystal-Shader.zip'
git archive --format=zip -o $full HEAD install.cmd config @common; Assert-Ok 'git archive'
git archive --format=zip -o $shader HEAD update-shader.cmd @common; Assert-Ok 'git archive'
Get-Item $full, $shader | ForEach-Object { '{0}  {1:N0} KB' -f $_.Name, ($_.Length / 1KB) }

if ($Publish) {
    git push -q origin HEAD; Assert-Ok 'git push'
    $notesFile = Join-Path $PSScriptRoot 'dist\notes.txt'
    [IO.File]::WriteAllText($notesFile, $Notes)
    gh release create "v$Version" $full $shader install.txt --repo $repo --target (git rev-parse HEAD) --title "v$Version" --notes-file $notesFile
    Assert-Ok 'gh release create'
}
