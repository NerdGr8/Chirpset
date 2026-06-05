#!/usr/bin/env bash
#
# Build, sign, notarize, and package Chirpset for direct distribution
# (outside the Mac App Store).
#
# Prerequisites
#   - A "Developer ID Application" certificate in your login keychain.
#   - A notarytool keychain profile (one-time setup):
#       xcrun notarytool store-credentials chirpset-notary \
#         --apple-id "you@example.com" --team-id "ABCDE12345" \
#         --password "app-specific-password"
#
# Configure via environment (or edit the defaults below):
#   DEV_ID_APP   "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE  notarytool keychain profile name (default: chirpset-notary)
#
# Usage:  Scripts/package.sh            # build + sign + notarize + staple + zip
#         SKIP_NOTARIZE=1 Scripts/package.sh   # build + sign only (local testing)

set -euo pipefail
cd "$(dirname "$0")/.."   # repo root (the dir containing Chirpset.xcodeproj)

PROJECT="Chirpset.xcodeproj"
SCHEME="Chirpset"
CONFIG="Release"
BUILD_DIR="$PWD/build"
EXPORT_DIR="$BUILD_DIR/export"
APP_NAME="Chirpset.app"

DEV_ID_APP="${DEV_ID_APP:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-chirpset-notary}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-0}"

echo "==> Clean build ($CONFIG)"
rm -rf "$BUILD_DIR"
mkdir -p "$EXPORT_DIR"

# Archive (Developer ID signing is applied at export time).
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination 'generic/platform=macOS' \
  -archivePath "$BUILD_DIR/Chirpset.xcarchive" \
  archive

APP_IN_ARCHIVE="$BUILD_DIR/Chirpset.xcarchive/Products/Applications/$APP_NAME"
cp -R "$APP_IN_ARCHIVE" "$EXPORT_DIR/"
APP="$EXPORT_DIR/$APP_NAME"

if [[ -n "$DEV_ID_APP" ]]; then
  echo "==> Re-signing with Developer ID (hardened runtime)"
  # Sign nested bundled tools first (deep), then the app.
  if [[ -d "$APP/Contents/Resources/tools" ]]; then
    find "$APP/Contents/Resources/tools" -type f -perm +111 -print0 | while IFS= read -r -d '' bin; do
      codesign --force --options runtime --timestamp \
        --sign "$DEV_ID_APP" "$bin"
    done
  fi
  codesign --force --deep --options runtime --timestamp \
    --entitlements "Chirpset/Chirpset.entitlements" \
    --sign "$DEV_ID_APP" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
else
  echo "!! DEV_ID_APP not set — using whatever signature xcodebuild produced (ad-hoc/dev)."
  echo "   Set DEV_ID_APP to a 'Developer ID Application' identity for distribution."
fi

ZIP="$BUILD_DIR/Chirpset.zip"
echo "==> Zipping for notarization"
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ "$SKIP_NOTARIZE" == "1" ]]; then
  echo "==> SKIP_NOTARIZE=1 — done. App at: $APP"
  exit 0
fi

if [[ -z "$DEV_ID_APP" ]]; then
  echo "!! Cannot notarize without a Developer ID signature. Set DEV_ID_APP. Aborting."
  exit 1
fi

echo "==> Submitting to Apple notary service (profile: $NOTARY_PROFILE)"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

# Re-zip the stapled app for shipping.
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Done. Notarized, stapled app: $APP"
echo "    Distributable archive:        $ZIP"
