#!/bin/sh
set -eu

PROJECT_DIR="${1:-/mnt/e/pony-fin-terminal}"
PONYUP_VERSION="${PONYUP_VERSION:-0.15.4}"
PONYC_VERSION="${PONYC_VERSION:-0.63.3}"
CORRAL_VERSION="${CORRAL_VERSION:-0.9.2}"
PONY_PREFIX="${PONY_PREFIX:-/opt/pony}"
PONYUP_DIR="${PONYUP_DIR:-/opt/ponyup}"
TOOLCHAIN_ROOT="${TOOLCHAIN_ROOT:-/opt/pony-linux}"

if [ "$(id -u)" = "0" ]; then
  mkdir -p /etc/sysconfig/tcedir/optional
  touch /etc/sysconfig/tcedir/onboot.lst
  chown -R tc:staff /etc/sysconfig/tcedir 2>/dev/null || true
  rm -f /usr/local/tce.installed/* 2>/dev/null || true
  rm -f /usr/local/etc/ssl/cacert.pem /usr/local/etc/ssl/ca-bundle.crt 2>/dev/null || true
  mkdir -p /lib64
  ln -sf /lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2
fi

if command -v tce-load >/dev/null 2>&1; then
  if [ "$(id -u)" = "0" ] && command -v su >/dev/null 2>&1; then
    su tc -c "tce-load -wi compiletc curl ca-certificates tar gzip" >/dev/null
  else
    tce-load -wi compiletc curl ca-certificates tar gzip >/dev/null
  fi
fi

export LD_LIBRARY_PATH="/usr/local/lib:/usr/lib:/lib:${LD_LIBRARY_PATH:-}"

mkdir -p "$PONYUP_DIR" "$PONY_PREFIX" "$TOOLCHAIN_ROOT"

if [ -n "${PONYC_ARCHIVE:-}" ] && [ -f "$PONYC_ARCHIVE" ]; then
  rm -rf "$TOOLCHAIN_ROOT/ponyc"
  mkdir -p "$TOOLCHAIN_ROOT/ponyc"
  tar -xzf "$PONYC_ARCHIVE" -C "$TOOLCHAIN_ROOT/ponyc"
fi

if [ -n "${CORRAL_ARCHIVE:-}" ] && [ -f "$CORRAL_ARCHIVE" ]; then
  rm -rf "$TOOLCHAIN_ROOT/corral"
  mkdir -p "$TOOLCHAIN_ROOT/corral"
  tar -xzf "$CORRAL_ARCHIVE" -C "$TOOLCHAIN_ROOT/corral"
fi

PONYC="$(find "$TOOLCHAIN_ROOT" -path "*/bin/ponyc" -type f | head -n 1)"

if [ -z "$PONYC" ]; then
  if [ ! -x "$PONYUP_DIR/bin/ponyup" ]; then
    curl -L \
      "https://github.com/ponylang/ponyup/releases/download/$PONYUP_VERSION/ponyup-x86-64-unknown-linux.tar.gz" \
      -o /tmp/ponyup.tar.gz
    tar -xzf /tmp/ponyup.tar.gz -C "$PONYUP_DIR"
  fi

  "$PONYUP_DIR/bin/ponyup" -p "$PONY_PREFIX" default x86_64-linux-ubuntu24.04
  "$PONYUP_DIR/bin/ponyup" -p "$PONY_PREFIX" --download-timeout=7200 update ponyc release "$PONYC_VERSION"
  "$PONYUP_DIR/bin/ponyup" -p "$PONY_PREFIX" --download-timeout=7200 update corral release "$CORRAL_VERSION"

  PONYC="$(find "$PONY_PREFIX/ponyup" -path "*/bin/ponyc" -type f | head -n 1)"
fi

if [ -z "$PONYC" ]; then
  echo "ponyc was not installed" >&2
  exit 1
fi

mkdir -p "$PROJECT_DIR/build/tinycore"
"$PONYC" "$PROJECT_DIR/src" --output "$PROJECT_DIR/build/tinycore" --bin-name pony-fin-terminal --verbose=0
