#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Awake"
INFO_PLIST="$ROOT_DIR/Resources/Info.plist"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")}"
BUILD_DIR="$ROOT_DIR/build/release"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
DIST_DIR="$ROOT_DIR/dist"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
FINAL_ZIP_VERSIONED="$DIST_DIR/$APP_NAME-$VERSION.zip"
FINAL_ZIP_LATEST="$DIST_DIR/$APP_NAME.zip"
CHECKSUMS_FILE="$DIST_DIR/checksums.txt"

cd "$ROOT_DIR"

rm -rf "$APP_DIR" "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$DIST_DIR"

swift build -c release
cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$INFO_PLIST" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ -n "$CODESIGN_IDENTITY" ]]; then
  echo "Signing with Developer ID identity: $CODESIGN_IDENTITY"
  /usr/bin/codesign --force --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_DIR"
else
  echo "No CODESIGN_IDENTITY set. Applying ad-hoc signature for local integrity only."
  /usr/bin/codesign --force --sign - "$APP_DIR"
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DIR"

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ -z "$CODESIGN_IDENTITY" ]]; then
    echo "NOTARY_PROFILE requires CODESIGN_IDENTITY." >&2
    exit 1
  fi

  NOTARY_ZIP="$DIST_DIR/$APP_NAME-notary.zip"
  /usr/bin/ditto -c -k --keepParent "$APP_DIR" "$NOTARY_ZIP"
  /usr/bin/xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  /usr/bin/xcrun stapler staple "$APP_DIR"
  /usr/sbin/spctl --assess --type execute --verbose=4 "$APP_DIR"
  rm -f "$NOTARY_ZIP"
fi

/usr/bin/ditto -c -k --keepParent "$APP_DIR" "$FINAL_ZIP_VERSIONED"
cp "$FINAL_ZIP_VERSIONED" "$FINAL_ZIP_LATEST"

(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 "$(basename "$FINAL_ZIP_VERSIONED")" "$(basename "$FINAL_ZIP_LATEST")" > "$CHECKSUMS_FILE"
)

echo "Created $FINAL_ZIP_VERSIONED"
echo "Created $FINAL_ZIP_LATEST"
echo "Created $CHECKSUMS_FILE"
