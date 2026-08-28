#!/usr/bin/env bash
set -euo pipefail

# Scripts directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Extract marketing version from project.pbxproj or use argument
VERSION="${1:-$(grep -m 1 'MARKETING_VERSION = ' LibrePaste.xcodeproj/project.pbxproj | awk '{print $3}' | tr -d ';')}"
BUILD_DIR="$PROJECT_ROOT/build"
RELEASE_DIR="$BUILD_DIR/release"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"
TEMP_DMG_DIR="$BUILD_DIR/dmg_temp"

echo "=================================================="
echo "🚀 Building LibrePaste v${VERSION} Release"
echo "=================================================="

# 1. Clean previous build artifacts
rm -rf "$RELEASE_DIR" "$TEMP_DMG_DIR"
mkdir -p "$RELEASE_DIR" "$TEMP_DMG_DIR"

# 2. Compile using xcodebuild
echo "📦 Compiling Release build..."
xcodebuild -scheme LibrePaste \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    clean build -quiet

APP_SOURCE="$DERIVED_DATA_DIR/Build/Products/Release/LibrePaste.app"
DSYM_SOURCE="$DERIVED_DATA_DIR/Build/Products/Release/LibrePaste.app.dSYM"

if [ ! -d "$APP_SOURCE" ]; then
    echo "❌ Error: Built application not found at $APP_SOURCE"
    exit 1
fi

# 3. Copy .app and .dSYM to release directory
echo "📋 Copying application artifacts..."
cp -R "$APP_SOURCE" "$RELEASE_DIR/LibrePaste.app"
if [ -d "$DSYM_SOURCE" ]; then
    cp -R "$DSYM_SOURCE" "$RELEASE_DIR/LibrePaste.app.dSYM"
fi

# 4. Create ZIP archive
ZIP_NAME="LibrePaste-v${VERSION}.zip"
echo "🗜️ Creating ZIP archive: $ZIP_NAME..."
ditto -c -k --sequesterRsrc --keepParent "$RELEASE_DIR/LibrePaste.app" "$RELEASE_DIR/$ZIP_NAME"

# 5. Create DMG image
DMG_NAME="LibrePaste-v${VERSION}.dmg"
echo "💿 Creating DMG image: $DMG_NAME..."
cp -R "$RELEASE_DIR/LibrePaste.app" "$TEMP_DMG_DIR/"
ln -s /Applications "$TEMP_DMG_DIR/Applications"

hdiutil create \
    -volname "LibrePaste" \
    -srcfolder "$TEMP_DMG_DIR" \
    -ov \
    -format UDZO \
    "$RELEASE_DIR/$DMG_NAME" > /dev/null

rm -rf "$TEMP_DMG_DIR"

# 6. Generate SHA256 checksums
echo "🔒 Generating SHA256 checksums..."
cd "$RELEASE_DIR"
shasum -a 256 "$ZIP_NAME" "$DMG_NAME" > checksums.txt

echo "=================================================="
echo "✅ Release build v${VERSION} completed successfully!"
echo "📂 Output artifacts in: $RELEASE_DIR"
cat checksums.txt
echo "=================================================="
