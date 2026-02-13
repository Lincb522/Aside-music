#!/bin/bash
set -e

# 从 .env 文件加载环境变量
if [ -f .env ]; then
    echo "Loading .env..."
    export $(grep -v '^#' .env | grep -v '^\s*$' | xargs)
fi

# 1. Clean
echo "Cleaning..."
rm -rf build Payload AsideMusic.ipa

# 2. Build（注入环境变量到 Info.plist）
echo "Building..."
xcodebuild -project AsideMusic.xcodeproj \
    -scheme AsideMusic \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath build \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    API_BASE_URL="${API_BASE_URL}" \
    clean build

# 3. Package
echo "Packaging..."
mkdir -p Payload
APP_PATH=$(find build/Build/Products/Release-iphoneos -name "*.app" | head -n 1)
cp -r "$APP_PATH" Payload/

# 4. 用 ldid 签入 entitlements（巨魔安装需要）
ENTITLEMENTS="Sources/AsideMusic/AsideMusic.entitlements"
if command -v ldid &> /dev/null && [ -f "$ENTITLEMENTS" ]; then
    echo "Signing with ldid..."
    ldid -S"$ENTITLEMENTS" "Payload/$(basename "$APP_PATH")/$(basename "$APP_PATH" .app)"
    echo "ldid signing done"
else
    echo "⚠️ ldid not found or entitlements missing, skipping signing"
fi

# 5. Zip
zip -r AsideMusic.ipa Payload

echo "Done! IPA created at AsideMusic.ipa"
