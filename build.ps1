<#
.SYNOPSIS
    Build fpcup (CLI installer tool) for Windows using an installed FPC.
.DESCRIPTION
    Invokes fpc.exe directly to compile fpcup.lpr for x86_64-win64.
    Output: upbin\fpcup-x86_64-win64.exe

    Unit search paths and compiler flags mirror the fpcup.lpi "win64" build mode.

.PARAMETER FpcDir
    Path to FPC bin directory containing fpc.exe.
    Default: C:\FPC\3.3.1\bin\x86_64-win64
.PARAMETER FpcLazUnitsDir
    Path to the compiled Lazarus/LCL unit directory (LCLBase, LazUtils).
    Default: C:\FPC\eleazar-free-pascal (lazbuild's FPC units are pre-installed here)
    Pass an empty string to skip adding this to the search path.
.PARAMETER BuildMode
    win32 or win64. Default: win64
.EXAMPLE
    .\build.ps1
.EXAMPLE
    .\build.ps1 -FpcDir C:\FPC\3.3.1\bin\x86_64-win64
.EXAMPLE
    .\build.ps1 -BuildMode win32 -FpcDir C:\FPC\3.2.2\bin\i386-win32
#>
param(
    [string]$FpcDir         = 'C:\FPC\3.3.1\bin\x86_64-win64',
    [string]$FpcLazUnitsDir = 'C:\FPC\eleazar-free-pascal',
    [ValidateSet('win32','win64')]
    [string]$BuildMode      = 'win64'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SrcDir = $PSScriptRoot

# ---- preflight: FPC ----------------------------------------------------------

$FpcExe = Join-Path $FpcDir 'fpc.exe'
if (-not (Test-Path $FpcExe)) {
    Write-Host "ERROR: FPC not found: $FpcExe" -ForegroundColor Red
    Write-Host "       Install FPC or pass -FpcDir <path>" -ForegroundColor Yellow
    exit 1
}
$FpcVer = (& $FpcExe -iV 2>&1).ToString().Trim()
Write-Host "FPC compiler : $FpcExe ($FpcVer)"

# ---- resolve target CPU/OS ---------------------------------------------------

if ($BuildMode -eq 'win64') {
    $TargetCPU = 'x86_64'
    $TargetOS  = 'win64'
} else {
    $TargetCPU = 'i386'
    $TargetOS  = 'win32'
}

$OutExe    = Join-Path $SrcDir "upbin\fpcup-${TargetCPU}-${TargetOS}.exe"
$UnitOutDir = Join-Path $SrcDir "buildlibs\fpcup\${TargetCPU}-${TargetOS}"

Write-Host "Target       : ${TargetCPU}-${TargetOS}"
Write-Host "Output       : $OutExe"
Write-Host "Started      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ''

# ---- create output dirs ------------------------------------------------------

foreach ($d in @((Split-Path $OutExe), $UnitOutDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null }
}

# ---- unit search paths (from fpcup.lpi) ------------------------------------
# sources;sources\up;sources\crossinstallers;synaser;dcpcrypt\Hashes;dcpcrypt;dcpcrypt\Ciphers

$UnitPaths = @(
    'sources'
    'sources\up'
    'sources\crossinstallers'
    'synaser'
    'dcpcrypt\Hashes'
    'dcpcrypt'
    'dcpcrypt\Ciphers'
)

$IncludePaths = @(
    'sources'
    'sources\up'
    'dcpcrypt\Ciphers'
    $UnitOutDir
)

# ---- build fpc arguments -----------------------------------------------------

$FpcArgs = [System.Collections.Generic.List[string]]::new()

# source file
$FpcArgs.Add((Join-Path $SrcDir 'fpcup.lpr'))

# target
$FpcArgs.Add("-P${TargetCPU}")
$FpcArgs.Add("-T${TargetOS}")

# optimisation and linking (win64 build mode: O2, smart link, strip)
$FpcArgs.Add('-O2')
$FpcArgs.Add('-XX')   # smart linking
$FpcArgs.Add('-CX')   # link smart units
$FpcArgs.Add('-Xs')   # strip debug symbols
$FpcArgs.Add('-l-')   # suppress FPC logo

# output
$FpcArgs.Add("-o${OutExe}")
$FpcArgs.Add("-FU${UnitOutDir}")

# unit search paths
foreach ($p in $UnitPaths) {
    $FpcArgs.Add("-Fu$(Join-Path $SrcDir $p)")
}

# include paths
foreach ($p in $IncludePaths) {
    $FpcArgs.Add("-Fi$(Join-Path $SrcDir $p)")
}

# optional extra Lazarus/LCL unit dir (LCLBase, LazUtils)
if ($FpcLazUnitsDir -ne '') {
    if (Test-Path $FpcLazUnitsDir) {
        $FpcArgs.Add("-Fu${FpcLazUnitsDir}")
    } else {
        Write-Host "WARNING: FpcLazUnitsDir not found: $FpcLazUnitsDir -- skipping" -ForegroundColor Yellow
    }
}

# defines
$FpcArgs.Add('-dFPCONLY')
$FpcArgs.Add('-dDisableRemoteLog')

# ---- invoke fpc --------------------------------------------------------------

Write-Host "Running: fpc $($FpcArgs -join ' ')"
Write-Host ''

& $FpcExe @FpcArgs 2>&1 | Tee-Object -FilePath (Join-Path $SrcDir 'build.log')
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host "=== Build FAILED (exit $LASTEXITCODE). See $SrcDir\build.log ===" -ForegroundColor Red
    exit $LASTEXITCODE
}

# ---- report ------------------------------------------------------------------

Write-Host ''
Write-Host "=== Build Complete: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -ForegroundColor Green
if (Test-Path $OutExe) {
    $info = Get-Item $OutExe
    $hash = (Get-FileHash $OutExe -Algorithm MD5).Hash.ToLower()
    Write-Host ("  {0}: {1} bytes  md5={2}  built={3}" -f `
        (Split-Path $OutExe -Leaf), $info.Length, $hash, `
        $info.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
}
Write-Host "  Build log : $SrcDir\build.log"
