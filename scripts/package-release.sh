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
FINAL_DMG_VERSIONED="$DIST_DIR/$APP_NAME-$VERSION.dmg"
FINAL_DMG_LATEST="$DIST_DIR/$APP_NAME.dmg"
CHECKSUMS_FILE="$DIST_DIR/checksums.txt"
DMG_RW="$BUILD_DIR/$APP_NAME-rw.dmg"
DMG_BACKGROUND_DIR=".background"
DMG_MOUNT_DIR=""
DMG_BACKGROUND_FILE=""

cd "$ROOT_DIR"

rm -rf "$APP_DIR" "$BUILD_DIR/dmg-volume" "$DMG_RW" "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$DIST_DIR"

create_dmg_background() {
  local output_path="$1"

  /usr/bin/swift - "$output_path" <<'SWIFT'
import AppKit

let outputPath = CommandLine.arguments[1]
let size = NSSize(width: 660, height: 420)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.94, green: 0.97, blue: 0.93, alpha: 1.0),
    NSColor(calibratedRed: 0.79, green: 0.88, blue: 0.80, alpha: 1.0)
])!
gradient.draw(in: rect, angle: 315)

NSColor(calibratedRed: 0.10, green: 0.15, blue: 0.10, alpha: 0.10).setFill()
NSBezierPath(ovalIn: NSRect(x: 430, y: 245, width: 220, height: 220)).fill()
NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.78, alpha: 0.45).setFill()
NSBezierPath(ovalIn: NSRect(x: -70, y: -65, width: 250, height: 250)).fill()

let title = "Install Awake"
let subtitle = "Drag Awake into Applications"
let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 34, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.08, alpha: 1.0)
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.17, green: 0.22, blue: 0.15, alpha: 0.78)
]
title.draw(at: NSPoint(x: 48, y: 338), withAttributes: titleAttributes)
subtitle.draw(at: NSPoint(x: 50, y: 308), withAttributes: subtitleAttributes)

let arrowAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 52, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 0.15, green: 0.25, blue: 0.13, alpha: 0.65)
]
"→".draw(at: NSPoint(x: 300, y: 166), withAttributes: arrowAttributes)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Failed to render DMG background.")
}

try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT
}

configure_dmg_finder_view() {
  /usr/bin/osascript <<APPLESCRIPT
set volumeRoot to POSIX file "$DMG_MOUNT_DIR" as alias
set backgroundImage to POSIX file "$DMG_BACKGROUND_FILE" as alias
tell application "Finder"
  open volumeRoot
  set current view of container window of volumeRoot to icon view
  try
    set toolbar visible of container window of volumeRoot to false
    set statusbar visible of container window of volumeRoot to false
  end try
  set bounds of container window of volumeRoot to {200, 120, 860, 540}
  set viewOptions to icon view options of container window of volumeRoot
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 104
  set background picture of viewOptions to backgroundImage
  set position of item "$APP_NAME.app" of volumeRoot to {170, 230}
  set position of item "Applications" of volumeRoot to {490, 230}
  update volumeRoot without registering applications
  delay 2
  try
    close container window of volumeRoot
  end try
end tell
APPLESCRIPT
}

detach_dmg() {
  local mount_dir="$1"

  for _ in 1 2 3 4 5; do
    if /usr/bin/hdiutil detach "$mount_dir" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  /usr/bin/hdiutil detach -force "$mount_dir" >/dev/null 2>&1 || true
}

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

APP_SIZE_KB=$(/usr/bin/du -sk "$APP_DIR" | /usr/bin/awk '{print $1}')
DMG_SIZE_MB=$((APP_SIZE_KB / 1024 + 48))
if (( DMG_SIZE_MB < 96 )); then
  DMG_SIZE_MB=96
fi

/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -size "${DMG_SIZE_MB}m" \
  -fs HFS+ \
  "$DMG_RW"
ATTACH_OUTPUT=$(/usr/bin/hdiutil attach \
  -readwrite \
  -noverify \
  -noautoopen \
  "$DMG_RW")
DMG_MOUNT_DIR=$(printf "%s\n" "$ATTACH_OUTPUT" | /usr/bin/awk -F '\t' '/Apple_HFS/ {print $NF; exit}')
if [[ -z "$DMG_MOUNT_DIR" || ! -d "$DMG_MOUNT_DIR" ]]; then
  echo "Failed to mount DMG." >&2
  printf "%s\n" "$ATTACH_OUTPUT" >&2
  exit 1
fi
DMG_BACKGROUND_FILE="$DMG_MOUNT_DIR/$DMG_BACKGROUND_DIR/background.png"
trap 'if [[ -n "${DMG_MOUNT_DIR:-}" && -d "$DMG_MOUNT_DIR" ]]; then detach_dmg "$DMG_MOUNT_DIR"; fi' EXIT

/usr/bin/ditto "$APP_DIR" "$DMG_MOUNT_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_MOUNT_DIR/Applications"
mkdir -p "$DMG_MOUNT_DIR/$DMG_BACKGROUND_DIR"
create_dmg_background "$DMG_BACKGROUND_FILE"
/usr/bin/chflags hidden "$DMG_MOUNT_DIR/$DMG_BACKGROUND_DIR" || true

if ! configure_dmg_finder_view; then
  echo "Warning: Finder DMG layout could not be applied. The DMG remains installable." >&2
fi

/bin/sync
detach_dmg "$DMG_MOUNT_DIR"
DMG_MOUNT_DIR=""
trap - EXIT
/usr/bin/hdiutil convert "$DMG_RW" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$FINAL_DMG_VERSIONED"
cp "$FINAL_DMG_VERSIONED" "$FINAL_DMG_LATEST"

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
