#!/bin/bash

set -e

echo "🏗️  Building Whale Release..."

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="Whale"

cd "$PROJECT_DIR"

# Clean previous builds
echo -e "${BLUE}Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Build Release
echo -e "${BLUE}Building Release configuration...${NC}"
xcodebuild build \
  -project Whale.xcodeproj \
  -scheme Whale \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  | xcpretty || xcodebuild build \
  -project Whale.xcodeproj \
  -scheme Whale \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
  echo "❌ Build failed: App not found at $APP_PATH"
  exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"
echo "📦 App location: $APP_PATH"

# Copy to dist
cp -R "$APP_PATH" "$DIST_DIR/"
echo "📦 Copied to: $DIST_DIR/$APP_NAME.app"

# Create DMG if create-dmg is installed
if command -v create-dmg &> /dev/null; then
  echo -e "${BLUE}Creating DMG...${NC}"
  
  create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 200 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 600 185 \
    "$DIST_DIR/$APP_NAME.dmg" \
    "$DIST_DIR/$APP_NAME.app" 2>/dev/null || true
  
  if [ -f "$DIST_DIR/$APP_NAME.dmg" ]; then
    echo -e "${GREEN}✅ DMG created: $DIST_DIR/$APP_NAME.dmg${NC}"
  fi
else
  echo "ℹ️  Tip: Install create-dmg to generate DMG files"
  echo "   brew install create-dmg"
fi

# Create ZIP
echo -e "${BLUE}Creating ZIP archive...${NC}"
cd "$DIST_DIR"
zip -r -q "$APP_NAME.zip" "$APP_NAME.app"
cd "$PROJECT_DIR"

echo -e "${GREEN}✅ ZIP created: $DIST_DIR/$APP_NAME.zip${NC}"

# Summary
echo ""
echo -e "${GREEN}🎉 Release build complete!${NC}"
echo ""
echo "📂 Output files:"
echo "   • App:  $DIST_DIR/$APP_NAME.app"
echo "   • ZIP:  $DIST_DIR/$APP_NAME.zip"
[ -f "$DIST_DIR/$APP_NAME.dmg" ] && echo "   • DMG:  $DIST_DIR/$APP_NAME.dmg"
echo ""
echo "To run the app:"
echo "   open $DIST_DIR/$APP_NAME.app"
echo ""
echo "To install to Applications:"
echo "   cp -R $DIST_DIR/$APP_NAME.app /Applications/"
