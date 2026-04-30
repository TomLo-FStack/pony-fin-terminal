#!/usr/bin/env sh
set -eu

BASE_DIR="${1:-.toolchains/pony-linux}"
PONYC_VERSION="${PONYC_VERSION:-0.63.3}"
CORRAL_VERSION="${CORRAL_VERSION:-0.9.2}"

mkdir -p "$BASE_DIR"

PONYC_URL="https://github.com/ponylang/ponyc/releases/download/$PONYC_VERSION/ponyc-x86-64-unknown-linux-ubuntu24.04.tar.gz"
CORRAL_URL="https://github.com/ponylang/corral/releases/download/$CORRAL_VERSION/corral-x86-64-unknown-linux.tar.gz"

if [ ! -x "$BASE_DIR/ponyc/bin/ponyc" ]; then
  rm -rf "$BASE_DIR/ponyc"
  mkdir -p "$BASE_DIR/ponyc"
  curl -L "$PONYC_URL" -o "$BASE_DIR/ponyc.tar.gz"
  tar -xzf "$BASE_DIR/ponyc.tar.gz" -C "$BASE_DIR/ponyc" --strip-components=1
fi

if [ ! -x "$BASE_DIR/corral/bin/corral" ]; then
  rm -rf "$BASE_DIR/corral"
  mkdir -p "$BASE_DIR/corral"
  curl -L "$CORRAL_URL" -o "$BASE_DIR/corral.tar.gz"
  tar -xzf "$BASE_DIR/corral.tar.gz" -C "$BASE_DIR/corral" --strip-components=1
fi

echo "$BASE_DIR/ponyc/bin"
