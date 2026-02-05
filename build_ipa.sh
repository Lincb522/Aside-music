#!/bin/bash
set -e

# 1. Clean
echo "Cleaning... (Modified by Trae)"
# rm -rf build Payload AuroraMusic.ipa

# 2. Build
echo "Building..."
xcodebuild -project AsideMusic.xcodeproj \
    -scheme AsideMusic \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath build \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    clean build

# 3. Package
echo "Packaging..."
mkdir -p Payload
APP_PATH=$(find build/Build/Products/Release-iphoneos -name "*.app" | head -n 1)
cp -r "$APP_PATH" Payload/

# 4. Pseudo-Sign
if command -v ldid &> /dev/null; then
    echo "Signing with ldid..."
    ldid -S Payload/AsideMusic.app
else
    echo "ldid not found. Skipping pseudo-signing."
fi

# 5. Zip
zip -r AsideMusic.ipa Payload

echo "Done! IPA created at AsideMusic.ipa"
