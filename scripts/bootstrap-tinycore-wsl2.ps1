[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$Distro = "TinyCorePony",
  [string]$HelperDistro = "",
  [string]$InstallRoot = "E:\wsl\TinyCorePony",
  [string]$WorkDir = "E:\toolchains\tinycore-wsl2",
  [string]$PonycVersion = "0.63.3",
  [string]$CorralVersion = "0.9.2",
  [switch]$Reimport,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$AppArgs
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$rootfsUrl = "http://tinycorelinux.net/17.x/x86_64/release/distribution_files/rootfs64.gz"
$rootfsMd5Url = "$rootfsUrl.md5.txt"
$rootfsGz = Join-Path $WorkDir "rootfs64.gz"
$rootfsTar = Join-Path $WorkDir "tinycore-rootfs.tar"
$ponycArchive = Join-Path $WorkDir "ponyc-$PonycVersion-x86-64-unknown-linux-ubuntu24.04.tar.gz"
$corralArchive = Join-Path $WorkDir "corral-$CorralVersion-x86-64-unknown-linux.tar.gz"
$ponycUrl = "https://github.com/ponylang/ponyc/releases/download/$PonycVersion/ponyc-x86-64-unknown-linux-ubuntu24.04.tar.gz"
$corralUrl = "https://github.com/ponylang/corral/releases/download/$CorralVersion/corral-x86-64-unknown-linux.tar.gz"

function Test-DistroExists([string]$Name) {
  $distros = @(wsl.exe --list --quiet 2>$null | ForEach-Object { ($_ -replace "`0", "").Trim() } | Where-Object { $_ })
  return ($distros -contains $Name)
}

function Convert-ToWslPath([string]$Path) {
  $full = [System.IO.Path]::GetFullPath($Path)
  return "/mnt/" + $full.Substring(0, 1).ToLower() + $full.Substring(2).Replace("\", "/")
}

function Get-HelperDistro([string]$Target, [string]$Requested) {
  if ($Requested) { return $Requested }
  $distros = @(wsl.exe --list --quiet 2>$null | ForEach-Object { ($_ -replace "`0", "").Trim() } | Where-Object { $_ -and ($_ -ne $Target) })
  if ($distros.Count -eq 0) {
    throw "A working helper WSL distro is required to create the Tiny Core tar with Unix permissions. Install any WSL distro first, or pass -HelperDistro."
  }
  return $distros[0]
}

if ($Reimport -and (Test-DistroExists $Distro)) {
  wsl.exe --terminate $Distro 2>$null
  wsl.exe --unregister $Distro
}

if (!(Test-DistroExists $Distro)) {
  New-Item -ItemType Directory -Force -Path $WorkDir, $InstallRoot | Out-Null

  if (!(Test-Path $rootfsGz)) {
    curl.exe -L -o $rootfsGz $rootfsUrl
    curl.exe -L -o "$rootfsGz.md5.txt" $rootfsMd5Url
  }

  $helper = Get-HelperDistro $Distro $HelperDistro
  $workForWsl = Convert-ToWslPath $WorkDir
  $rootfsForWsl = Convert-ToWslPath $rootfsGz
  $tarForWsl = Convert-ToWslPath $rootfsTar
  $makeTarScript = Join-Path $WorkDir "make-rootfs-tar.sh"
  $makeTarScriptForWsl = Convert-ToWslPath $makeTarScript

  $makeTar = @'
set -eu
tmp_root="/tmp/tinycore-rootfs-$$"
rootfs_gz="__ROOTFS_GZ__"
tar_out="__ROOTFS_TAR__"
rm -rf "$tmp_root" "$tar_out"
mkdir -p "$tmp_root"
gzip -dc "$rootfs_gz" | (cd "$tmp_root" && cpio -idm --quiet) 2>/tmp/tinycore-cpio.log || true
rm -rf "$tmp_root/dev"
mkdir -p "$tmp_root/dev"
mkdir -p "$tmp_root/lib64"
ln -sf /lib/ld-linux-x86-64.so.2 "$tmp_root/lib64/ld-linux-x86-64.so.2"
mkdir -p "$tmp_root/etc/sysconfig"
mkdir -p "$tmp_root/etc/sysconfig/tcedir/optional"
touch "$tmp_root/etc/sysconfig/tcedir/onboot.lst"
printf 'tc\n' > "$tmp_root/etc/sysconfig/tcuser"
: > "$tmp_root/etc/sysconfig/superuser"
cat > "$tmp_root/etc/wsl.conf" <<'EOF'
[automount]
enabled=true
root=/mnt/

[interop]
enabled=true
appendWindowsPath=false
EOF
tar --numeric-owner -cpf "$tar_out" -C "$tmp_root" .
rm -rf "$tmp_root"
'@
  $makeTar = $makeTar.Replace("__ROOTFS_GZ__", $rootfsForWsl).Replace("__ROOTFS_TAR__", $tarForWsl)
  Set-Content -LiteralPath $makeTarScript -Value $makeTar -Encoding ASCII

  wsl.exe -d $helper -- /bin/sh $makeTarScriptForWsl
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  wsl.exe --import $Distro $InstallRoot $rootfsTar --version 2
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
if (!(Test-Path $ponycArchive)) {
  curl.exe -L -o $ponycArchive $ponycUrl
}
if (!(Test-Path $corralArchive)) {
  curl.exe -L -o $corralArchive $corralUrl
}

$projectForWsl = Convert-ToWslPath $projectRoot
$ponycArchiveForWsl = Convert-ToWslPath $ponycArchive
$corralArchiveForWsl = Convert-ToWslPath $corralArchive

$buildCommand = "PONYC_ARCHIVE='$ponycArchiveForWsl' CORRAL_ARCHIVE='$corralArchiveForWsl' /bin/sh '$projectForWsl/scripts/build-tinycore.sh' '$projectForWsl'"
wsl.exe -d $Distro --exec /bin/sh -lc $buildCommand
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($AppArgs.Count -gt 0) {
  $quotedArgs = ($AppArgs | ForEach-Object { "'" + ($_ -replace "'", "'\''") + "'" }) -join " "
  wsl.exe -d $Distro --exec /bin/sh -lc "cd '$projectForWsl' && ./build/tinycore/pony-fin-terminal $quotedArgs"
} else {
  wsl.exe -d $Distro --exec /bin/sh -lc "cd '$projectForWsl' && ./build/tinycore/pony-fin-terminal watch"
}
