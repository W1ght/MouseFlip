#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
case "$MODE" in run|--build-only|--verify|--debug|--logs|--telemetry) ;; *) echo "Usage: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;; esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="MouseFlip"
BUNDLE_ID="local.mouseflip.app"
APP_BUNDLE="$ROOT_DIR/dist/MouseFlip.app"
if [[ "$MODE" != "--build-only" ]]; then pkill -x "$APP_NAME" >/dev/null 2>&1 || true; fi
swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BUILD_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MouseFlip</string>
<key>CFBundleIdentifier</key><string>local.mouseflip.app</string>
<key>CFBundleName</key><string>MouseFlip</string>
<key>CFBundleDisplayName</key><string>MouseFlip</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/bin/codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
case "$MODE" in
  --build-only) echo "Built: $APP_BUNDLE" ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "MouseFlip"' ;;
  --telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "local.mouseflip.app"' ;;
  --verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 2; pgrep -x "$APP_NAME"; echo "Launch verified" ;;
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
