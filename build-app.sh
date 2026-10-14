#!/bin/bash
# Builds "Markdown Viewer.app" into ./build. Needs only the Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Markdown Viewer.app"
CONFIG="${1:-release}"

# The default (swiftbuild) system needs full Xcode; native works with the CLT.
swift build -c "$CONFIG" --build-system native 2>&1 | grep -v "has been deprecated" || true
BIN="$(swift build -c "$CONFIG" --build-system native --show-bin-path 2>/dev/null)/MarkdownViewer"
[ -x "$BIN" ] || { echo "Build failed"; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MarkdownViewer"
cp Support/Info.plist "$APP/Contents/Info.plist"

# App icon
ICON_WORK="$(mktemp -d)"
trap 'rm -rf "$ICON_WORK"' EXIT
swift Support/make-icon.swift "$ICON_WORK/icon.png"
ICONSET="$ICON_WORK/AppIcon.iconset"
mkdir "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICON_WORK/icon.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$ICON_WORK/icon.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP"
# Re-register so Finder picks up document types and the icon.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"

echo "Built $APP"
