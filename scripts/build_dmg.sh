#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LightMD Reader"
APP_BUNDLE="$ROOT_DIR/build/$APP_NAME.app"
DMG_ROOT="$ROOT_DIR/build/dmg-root"
DMG_RW="$ROOT_DIR/build/$APP_NAME-rw.dmg"
DMG_PATH="$ROOT_DIR/build/$APP_NAME.dmg"
BACKGROUND="$ROOT_DIR/Assets/DMGBackground.png"
VOLUME_PATH="/Volumes/$APP_NAME"
BACKGROUND_IN_VOLUME="$VOLUME_PATH/.background/DMGBackground.png"

"$ROOT_DIR/scripts/build_app.sh"
python3 "$ROOT_DIR/scripts/generate_dmg_background.py"

rm -rf "$DMG_ROOT" "$DMG_RW" "$DMG_PATH"
mkdir -p "$DMG_ROOT/.background"
cp -R "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
cp "$BACKGROUND" "$DMG_ROOT/.background/DMGBackground.png"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDRW \
  "$DMG_RW" >/dev/null

hdiutil attach "$DMG_RW" -nobrowse -quiet

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set sidebar width of container window to 0
    set bounds of container window to {120, 120, 760, 480}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 112
    set background picture of theViewOptions to POSIX file "$BACKGROUND_IN_VOLUME"
    set position of item "$APP_NAME.app" of container window to {168, 200}
    set position of item "Applications" of container window to {472, 200}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$VOLUME_PATH" -quiet

hdiutil convert "$DMG_RW" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" >/dev/null

rm -rf "$DMG_ROOT" "$DMG_RW"

echo "Built: $DMG_PATH"
