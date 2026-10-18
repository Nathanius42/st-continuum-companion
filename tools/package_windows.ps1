<#
.SYNOPSIS
  Build the Windows downloads: a portable zip and an NSIS installer (#552, #553, #608).

.DESCRIPTION
  Builds the release app, stages it with the Visual C++ runtime DLLs it needs
  (app-local, so a clean Windows machine runs it without installing the
  redistributable), zips the staged folder, then compiles installer\ContinuumDex.nsi.

  Outputs go to dist\ (git-ignored):
    dist\ContinuumCompanion-<version>-windows-x64.zip
    dist\ContinuumCompanion-<version>-setup.exe

  makensis is found from -Makensis, the NSIS environment variable, a standard NSIS 3
  install, or the mod's NSIS 2.46 in that order. The pipeline uses NSIS 3.

.PARAMETER SkipBuild
  Package the existing build instead of running flutter build windows.
#>
param(
    [string]$Flutter = 'D:\Dev\flutter\bin\flutter.bat',
    [string]$Makensis,
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'app'
$dist = Join-Path $root 'dist'

$version = (Select-String -Path (Join-Path $app 'pubspec.yaml') -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
Write-Host "Continuum Companion $version"

if (-not $SkipBuild) {
    Push-Location $app
    try { & $Flutter build windows --release; if ($LASTEXITCODE) { throw 'flutter build windows failed' } }
    finally { Pop-Location }
}
$release = Join-Path $app 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'continuum_companion.exe'))) { throw "No release build in $release" }

# Stage: the build plus the Visual C++ runtime, app-local.
$stage = Join-Path $dist "ContinuumCompanion-$version"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null
Copy-Item -Recurse -Path (Join-Path $release '*') -Destination $stage
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    Copy-Item (Join-Path $env:SystemRoot "System32\$dll") $stage
}
Copy-Item (Join-Path $root 'installer\notice.txt') $stage

$zip = Join-Path $dist "ContinuumCompanion-$version-windows-x64.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $stage -DestinationPath $zip
Write-Host "Zip: $zip ($([math]::Round((Get-Item $zip).Length / 1MB, 1)) MB)"

# Installer.
$candidates = @(@($Makensis, $(if ($env:NSIS) { Join-Path $env:NSIS 'makensis.exe' }),
    'C:\Program Files (x86)\NSIS\makensis.exe', 'C:\Program Files\NSIS\makensis.exe',
    'D:\Modding Tools\HW2TREKMOD\HWRM\Tools\Installer and Launcher\NSIS modified\makensis.exe') | Where-Object { $_ -and (Test-Path $_) })
if (-not $candidates) { Write-Warning 'makensis not found; skipping the installer.'; return }
$nsis = $candidates[0]
$setup = Join-Path $dist "ContinuumCompanion-$version-setup.exe"
Push-Location (Join-Path $root 'installer')
try {
    & $nsis /V2 "/DSOURCE=$stage" "/DVERSION=$version" "/DOUTFILE=$setup" ContinuumDex.nsi
    if ($LASTEXITCODE) { throw "makensis failed ($nsis)" }
}
finally { Pop-Location }
Write-Host "Installer: $setup ($([math]::Round((Get-Item $setup).Length / 1MB, 1)) MB), built with $nsis"
