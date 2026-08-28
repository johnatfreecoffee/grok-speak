#!/usr/bin/env bash
# Build Grok Speak.app (ad-hoc signed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build"
APP="$BUILD/Grok Speak.app"
BIN="$APP/Contents/MacOS/GrokSpeak"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ICONSET="$ROOT/app/Resources/GrokSpeak.iconset"
ICNS="$ROOT/app/Resources/GrokSpeak.icns"
SRC1024="$ROOT/app/Resources/icon-1024.png"

if [[ ! -f "$SRC1024" ]]; then
  echo "missing $SRC1024" >&2
  exit 1
fi

if [[ ! -f "$ICNS" || "$SRC1024" -nt "$ICNS" ]]; then
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  sips -s format png "$SRC1024" --out /tmp/grok-speak-1024.png >/dev/null
  make_icon() { sips -z "$1" "$1" /tmp/grok-speak-1024.png --out "$ICONSET/$2" >/dev/null; }
  make_icon 16 icon_16x16.png
  make_icon 32 icon_16x16@2x.png
  make_icon 32 icon_32x32.png
  make_icon 64 icon_32x32@2x.png
  make_icon 128 icon_128x128.png
  make_icon 256 icon_128x128@2x.png
  make_icon 256 icon_256x256.png
  make_icon 512 icon_256x256@2x.png
  make_icon 512 icon_512x512.png
  make_icon 1024 icon_512x512@2x.png
  iconutil -c icns "$ICONSET" -o "$ICNS"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library \
  -target arm64-apple-macosx14.0 \
  -sdk "$SDK" \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework MediaPlayer \
  -framework Combine \
  -o "$BIN" \
  "$ROOT"/app/Sources/*.swift

cp "$ROOT/app/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ICNS" "$APP/Contents/Resources/GrokSpeak.icns"
echo -n 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --deep --sign - "$APP" >/dev/null
echo "$APP"
