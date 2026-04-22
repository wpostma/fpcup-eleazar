<#
.SYNOPSIS
    Build fpcupdeluxe for Windows using lazbuild.
.DESCRIPTION
    Uses lazbuild.exe to compile fpcupdeluxe.lpi, which resolves all package
    dependencies (LCL, SynEdit, etc.) automatically.

.PARAMETER LazBuild
    Path to lazbuild.exe. Default: C:\FPC\eleazar-free-pascal\lazbuild.exe
.PARAMETER FpcDir
    Path to FPC bin directory. Default: C:\FPC\3.3.1\bin\x86_64-win64
.PARAMETER BuildMode
    lazbuild build mode from fpcupdeluxe.lpi. Default: Default
.EXAMPLE
    .\build.ps1
.EXAMPLE
    .\build.ps1 -BuildMode win64
#>
param(
    [string]$LazBuild  = 'C:\FPC\fpcup_trunk\lazarus\lazbuild.exe',
    [string]$FpcDir    = 'C:\FPC\fpcup_trunk\fpc\bin\i386-win32',
    [string]$BuildMode = 'win32'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$FpcExe = Join-Path $FpcDir 'fpc.exe'
$Lpi    = Join-Path $PSScriptRoot 'fpcupdeluxe.lpi'

if (-not (Test-Path $LazBuild)) {
    Write-Host "ERROR: lazbuild not found: $LazBuild" -ForegroundColor Red; exit 1
}
if (-not (Test-Path $FpcExe)) {
    Write-Host "ERROR: fpc.exe not found: $FpcExe" -ForegroundColor Red; exit 1
}
if (-not (Test-Path $Lpi)) {
    Write-Host "ERROR: project file not found: $Lpi" -ForegroundColor Red; exit 1
}

Write-Host "lazbuild    : $LazBuild"
Write-Host "FPC         : $FpcExe"
Write-Host "Project     : $Lpi"
Write-Host "Build mode  : $BuildMode"
Write-Host "Started     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

Push-Location $PSScriptRoot
try {
    & $LazBuild --compiler="$FpcExe" "--build-mode=$BuildMode" $Lpi
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "=== Build FAILED (exit $LASTEXITCODE) ===" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== Build Complete: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -ForegroundColor Green
