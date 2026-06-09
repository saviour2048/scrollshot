#!/bin/bash
#
# Build → sign (Developer ID) → notarize → staple → package a distributable
# ScrollShot.app + ScrollShot.dmg. Run on a Mac, from the ScrollShot dir:
#
#     ./scripts/build_notarize.sh
#
# Prerequisites (one-time):
#   1. Apple Developer Program membership.
#   2. A "Developer ID Application" certificate in your login keychain
#      (Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ + Developer ID Application).
#   3. Store notary credentials once:
#        xcrun notarytool store-credentials scrollshot-notary \
#          --apple-id "zhangtongwei@gmail.com" --team-id 5QZY8FV25Y
#      (it'll ask for an app-specific password from appleid.apple.com)
#
# Override the notary profile name with: NOTARY_PROFILE=xxx ./scripts/build_notarize.sh

set -euo pipefail
cd "$(dirname "$0")/.."   # → ScrollShot project dir

NOTARY_PROFILE="${NOTARY_PROFILE:-scrollshot-notary}"
BUILD_DIR="build"
ARCHIVE="$BUILD_DIR/ScrollShot.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/ScrollShot.app"
ZIP="$BUILD_DIR/ScrollShot.zip"
DMG="$BUILD_DIR/ScrollShot.dmg"

echo "▸ Regenerating project + app icon…"
command -v xcodegen >/dev/null && xcodegen generate || echo "  (xcodegen not found, using existing .xcodeproj)"
swift scripts/make_icon.swift || echo "  (icon generation skipped)"
command -v xcodegen >/dev/null && xcodegen generate || true

rm -rf "$BUILD_DIR"

echo "▸ Archiving (Release)…"
xcodebuild -project ScrollShot.xcodeproj -scheme ScrollShot \
  -configuration Release -archivePath "$ARCHIVE" \
  archive | xcpretty 2>/dev/null || xcodebuild -project ScrollShot.xcodeproj -scheme ScrollShot \
  -configuration Release -archivePath "$ARCHIVE" archive

echo "▸ Exporting with Developer ID…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath "$EXPORT_DIR"

if [ -n "${SKIP_NOTARIZE:-}" ]; then
  echo "▸ SKIP_NOTARIZE set — skipping notarization (DMG will be signed but not notarized)."
else
  echo "▸ Zipping for notarization…"
  ditto -c -k --keepParent "$APP" "$ZIP"

  echo "▸ Submitting to Apple notary service (this can take a few minutes)…"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

  echo "▸ Stapling ticket…"
  xcrun stapler staple "$APP"
fi

echo "▸ Building DMG…"
rm -f "$DMG"
hdiutil create -volname "ScrollShot" -srcfolder "$APP" -ov -format UDZO "$DMG"

echo ""
echo "✅ Done."
echo "   App:  $APP"
echo "   DMG:  $DMG   ← 把这个发给别人,双击安装即可"
echo ""
echo "验证签名/公证:"
echo "   spctl -a -vvv \"$APP\""
echo "   xcrun stapler validate \"$APP\""
