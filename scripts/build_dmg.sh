#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LightMD Reader"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
DMG_ROOT="$ROOT_DIR/build/dmg-root"
DMG_PATH="$ROOT_DIR/build/$APP_NAME.dmg"

"$ROOT_DIR/scripts/build_app.sh"

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"
cp -R "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$DMG_ROOT"

echo "Built: $DMG_PATH"
