param(
  [string]$PonyBaseDir = "E:\toolchains\pony",
  [string]$PonycVersion = "0.63.3"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $projectRoot "build"
$ponyc = Join-Path $PonyBaseDir "ponyup-root\ponyup\ponyc-release-$PonycVersion-x86_64-windows\bin\ponyc.exe"

if (!(Test-Path $ponyc)) {
  & (Join-Path $PSScriptRoot "install-pony-windows.ps1") -BaseDir $PonyBaseDir -PonycVersion $PonycVersion
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$link = Get-Command link.exe -ErrorAction SilentlyContinue
if ($link) {
  & $ponyc (Join-Path $projectRoot "src") --output $buildDir --bin-name pony-fin-terminal --verbose=0
  exit $LASTEXITCODE
}

$vswhere = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if (!(Test-Path $vswhere)) {
  throw "MSVC link.exe was not found. Install Visual Studio Build Tools with the C++ build tools workload."
}

$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vsPath) {
  throw "MSVC C++ tools were not found. Install Visual Studio Build Tools and select Desktop development with C++."
}

$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
if (!(Test-Path $vcvars)) {
  throw "vcvars64.bat was not found under $vsPath."
}

$cmd = "`"$vcvars`" && `"$ponyc`" `"$projectRoot\src`" --output `"$buildDir`" --bin-name pony-fin-terminal --verbose=0"
cmd.exe /c $cmd
exit $LASTEXITCODE
