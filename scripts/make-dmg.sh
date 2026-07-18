#!/bin/bash
# Builds Mac Harmonium.app from the SPM release build and packages it into a DMG.
set -euo pipefail

APP_NAME="Mac Harmonium"
EXEC_NAME="Harmonium"
BUNDLE_ID="com.sunnyjoshi.MacHarmonium"
VERSION="1.1"
BUILD="2"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_SRC="$ROOT/Sources/Harmonium/Resources/AppIcon.png"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "==> Release build"
swift build -c release --package-path "$ROOT"
RELEASE="$ROOT/.build/release"

echo "==> Scaffolding app bundle"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$RELEASE/$EXEC_NAME" "$APP/Contents/MacOS/$EXEC_NAME"
cp -R "$RELEASE/${EXEC_NAME}_${EXEC_NAME}.bundle" "$APP/Contents/Resources/"

echo "==> Building AppIcon.icns"
ICONSET="$DIST/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16   16   "$ICON_SRC" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32   32   "$ICON_SRC" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32   32   "$ICON_SRC" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64   64   "$ICON_SRC" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128  128  "$ICON_SRC" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256  256  "$ICON_SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256  256  "$ICON_SRC" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512  512  "$ICON_SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512  512  "$ICON_SRC" --out "$ICONSET/icon_512x512.png"    >/dev/null
sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "==> Writing Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>$APP_NAME</string>
	<key>CFBundleDisplayName</key><string>$APP_NAME</string>
	<key>CFBundleExecutable</key><string>$EXEC_NAME</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>$BUILD</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>LSApplicationCategoryType</key><string>public.app-category.music</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc signing"
xattr -cr "$APP"                      # strip extended attributes that block signing
codesign --force --deep --sign - "$APP"

echo "==> Creating DMG"
DMG="$DIST/Mac-Harmonium.dmg"
STAGING="$DIST/staging"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo ""
echo "Done ✅  $DMG"
