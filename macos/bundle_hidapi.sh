#!/usr/bin/env bash
# Copies libhidapi into the built .app so it runs without Homebrew installed.
# Usage: macos/bundle_hidapi.sh build/macos/Build/Products/Release/fx200_studio.app
set -euo pipefail
APP="${1:?path to .app}"
SRC="$(brew --prefix hidapi)/lib/libhidapi.dylib"
DEST="$APP/Contents/Frameworks"
mkdir -p "$DEST"
cp -L "$SRC" "$DEST/libhidapi.dylib"
install_name_tool -id "@rpath/libhidapi.dylib" "$DEST/libhidapi.dylib"
# Ad-hoc signature so Gatekeeper accepts the modified bundle locally.
codesign --force --deep --sign - "$APP"
