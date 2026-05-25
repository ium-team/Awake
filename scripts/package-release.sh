#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Awake"
INFO_PLIST="$ROOT_DIR/Resources/Info.plist"
APP_ICON="$ROOT_DIR/Resources/AppIcon.icns"
DMG_LAYOUT="$ROOT_DIR/Resources/DMGLayout.dsstore"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")}"
BUILD_DIR="$ROOT_DIR/build/release"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_STAGE_DIR="$BUILD_DIR/dmg-volume"
DMG_VOLUME_NAME="$APP_NAME Installer"
DIST_DIR="$ROOT_DIR/dist"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
FINAL_ZIP_VERSIONED="$DIST_DIR/$APP_NAME-$VERSION.zip"
FINAL_ZIP_LATEST="$DIST_DIR/$APP_NAME.zip"
FINAL_DMG_VERSIONED="$DIST_DIR/$APP_NAME-$VERSION.dmg"
FINAL_DMG_LATEST="$DIST_DIR/$APP_NAME.dmg"
CHECKSUMS_FILE="$DIST_DIR/checksums.txt"

cd "$ROOT_DIR"

rm -rf "$APP_DIR" "$DMG_STAGE_DIR" "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$DMG_STAGE_DIR" "$DIST_DIR"

swift build -c release
cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$INFO_PLIST" "$CONTENTS_DIR/Info.plist"
cp "$APP_ICON" "$RESOURCES_DIR/AppIcon.icns"
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

# Use a committed Finder layout and build from an unmounted source folder.
# A writable mounted image can persist .fseventsd and background support files.
/usr/bin/ditto "$APP_DIR" "$DMG_STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_STAGE_DIR/Applications"
cp "$DMG_LAYOUT" "$DMG_STAGE_DIR/.DS_Store"
/usr/bin/chflags hidden "$DMG_STAGE_DIR/.DS_Store" || true

/usr/bin/hdiutil create \
  -volname "$DMG_VOLUME_NAME" \
  -srcfolder "$DMG_STAGE_DIR" \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$FINAL_DMG_VERSIONED"
cp "$FINAL_DMG_VERSIONED" "$FINAL_DMG_LATEST"

verify_dmg_contents() {
  local attach_output mount_dir unexpected=""
  attach_output=$(/usr/bin/hdiutil attach -readonly -nobrowse -noautoopen "$FINAL_DMG_VERSIONED")
  mount_dir=$(printf "%s\n" "$attach_output" | /usr/bin/awk -F '\t' '/\/Volumes\// {print $NF; exit}')
  if [[ -z "$mount_dir" || ! -d "$mount_dir" ]]; then
    echo "Failed to mount the completed DMG for verification." >&2
    printf "%s\n" "$attach_output" >&2
    exit 1
  fi

  if [[ ! -d "$mount_dir/$APP_NAME.app" || ! -L "$mount_dir/Applications" || ! -f "$mount_dir/.DS_Store" ]]; then
    /usr/bin/hdiutil detach "$mount_dir" >/dev/null
    echo "DMG validation failed: required installer entries are missing." >&2
    exit 1
  fi

  while IFS= read -r item; do
    case "$(basename "$item")" in
      "$APP_NAME.app"|Applications|.DS_Store) ;;
      *) unexpected="${unexpected} $(basename "$item")" ;;
    esac
  done < <(/usr/bin/find "$mount_dir" -mindepth 1 -maxdepth 1 -print)

  /usr/bin/hdiutil detach "$mount_dir" >/dev/null
  if [[ -n "$unexpected" ]]; then
    echo "DMG validation failed: unexpected root entries:$unexpected" >&2
    exit 1
  fi
}

verify_dmg_contents

(
  cd "$DIST_DIR"
  /usr/bin/shasum -a 256 \
    "$(basename "$FINAL_DMG_VERSIONED")" \
    "$(basename "$FINAL_DMG_LATEST")" \
    "$(basename "$FINAL_ZIP_VERSIONED")" \
    "$(basename "$FINAL_ZIP_LATEST")" \
    > "$CHECKSUMS_FILE"
)

echo "Created $FINAL_DMG_VERSIONED"
echo "Created $FINAL_DMG_LATEST"
echo "Created $FINAL_ZIP_VERSIONED"
echo "Created $FINAL_ZIP_LATEST"
echo "Created $CHECKSUMS_FILE"
