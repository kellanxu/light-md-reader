#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LightMD.app"
BUILT_APP="$ROOT_DIR/build/$APP_NAME"
INSTALL_DIR="$HOME/Applications"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"$ROOT_DIR/scripts/build_app.sh"

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALLED_APP"
cp -R "$BUILT_APP" "$INSTALLED_APP"

"$LSREGISTER" -f "$INSTALLED_APP"

swift -e 'import Foundation; import CoreServices; let bundle = "com.kellan.lightmd" as NSString; for type in ["net.daringfireball.markdown", "public.markdown"] { let uti = type as NSString; for role in [LSRolesMask.viewer, LSRolesMask.editor, LSRolesMask.all] { let status = LSSetDefaultRoleHandlerForContentType(uti, role, bundle); if status != 0 { exit(1) } } }'

echo "Installed: $INSTALLED_APP"
echo "Default Markdown handler: com.kellan.lightmd"
