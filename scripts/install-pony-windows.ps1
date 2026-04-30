param(
  [string]$BaseDir = "E:\toolchains\pony",
  [string]$Platform = "x86-64-pc-windows-msvc",
  [string]$PonyupVersion = "0.15.4",
  [string]$PonycVersion = "0.63.3",
  [string]$CorralVersion = "0.9.2"
)

$ErrorActionPreference = "Stop"

$ponyupZipName = "ponyup-x86-64-pc-windows-msvc.zip"
$ponyupUrl = "https://github.com/ponylang/ponyup/releases/download/$PonyupVersion/$ponyupZipName"
$ponyupZip = Join-Path $BaseDir "ponyup-$PonyupVersion-x86-64-pc-windows-msvc.zip"
$ponyupDir = Join-Path $BaseDir "ponyup-$PonyupVersion"
$prefix = Join-Path $BaseDir "ponyup-root"
$ponyupExe = Join-Path $ponyupDir "bin\ponyup.exe"

New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $prefix "ponyup") | Out-Null

if (!(Test-Path $ponyupZip)) {
  curl.exe -L -o $ponyupZip $ponyupUrl
}

if (!(Test-Path $ponyupExe)) {
  if (Test-Path $ponyupDir) {
    Remove-Item -Recurse -Force -LiteralPath $ponyupDir
  }
  Expand-Archive -LiteralPath $ponyupZip -DestinationPath $ponyupDir
}

& $ponyupExe -p $prefix default $Platform
& $ponyupExe -p $prefix --download-timeout=7200 update ponyc release $PonycVersion
& $ponyupExe -p $prefix --download-timeout=7200 update corral release $CorralVersion

$ponyc = Join-Path $prefix "ponyup\ponyc-release-$PonycVersion-x86_64-windows\bin\ponyc.exe"
$corral = Join-Path $prefix "ponyup\corral-release-$CorralVersion-x86_64-windows\bin\corral.exe"

& $ponyc --version
& $corral version

