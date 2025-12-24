#!/bin/bash

ICON_SOURCE="Resources/icon_1024.png"
ICON_DEST="Resources/AppIcon.icns"

# 1. Process Icon (Only if needed)
if [ -f "$ICON_DEST" ]; then
    echo "✅ Icon already exists at $ICON_DEST, skipping generation."
else
    if [ ! -f "$ICON_SOURCE" ]; then
        echo "❌ Error: $ICON_SOURCE not found."
        echo "Please place your 1024x1024 PNG icon at 'Resources/icon_1024.png' before running this script."
        exit 1
    fi

    echo "🎨 Processing Icon from $ICON_SOURCE..."
    mkdir -p Resources/AppIcon.iconset

    # Generate various sizes
    sips -z 16 16     "$ICON_SOURCE" --out Resources/AppIcon.iconset/icon_16x16.png > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out Resources/AppIcon.iconset/icon_16x16@2x.png > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out Resources/AppIcon.iconset/icon_32x32.png > /dev/null
    sips -z 64 64     "$ICON_SOURCE" --out Resources/AppIcon.iconset/icon_32x32@2x.png > /dev/null
    sips -z 128 128   "$ICON_SOURCE" --out Resources/AppIcon.iconset/icon_128x128.png > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out Resources/AppIcon.iconset/icon_128x128@2x.png > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out Resources/AppIcon.iconset/icon_256x256.png > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out Resources/AppIcon.iconset/icon_256x256@2x.png > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out Resources/AppIcon.iconset/icon_512x512.png > /dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out Resources/AppIcon.iconset/icon_512x512@2x.png > /dev/null

    # Convert to icns
    iconutil -c icns Resources/AppIcon.iconset -o "$ICON_DEST"
    
    # Cleanup
    rm -rf Resources/AppIcon.iconset
fi

# 2. Build using xcodebuild
echo "🔨 Building Project..."
# Remove previous build artifacts to ensure a fresh build
rm -rf .build/release
rm -rf .build/DerivedData
# Build using SwiftPM (keeps artifacts under .build/)
MODULE_CACHE_DIR=".build/module-cache"
rm -rf "$MODULE_CACHE_DIR"
CLANG_MODULE_CACHE_DIR=".build/clang-module-cache"
TMPDIR_OVERRIDE="$PWD/.build/tmp"

mkdir -p "$CLANG_MODULE_CACHE_DIR" "$TMPDIR_OVERRIDE"

SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
CLANG_RESOURCE_DIR="$(xcrun --toolchain XcodeDefault.xctoolchain clang -print-resource-dir)/include"

# Avoid Homebrew /usr/local/include modulemaps by pinning headers to the SDK only
env -u CPATH -u C_INCLUDE_PATH -u OBJC_INCLUDE_PATH \
    CLANG_MODULE_CACHE_PATH="$CLANG_MODULE_CACHE_DIR" \
    TMPDIR="$TMPDIR_OVERRIDE" \
    swift build -c release --product TemporaryAI \
    -Xcc -nostdinc \
    -Xcc -isystem"$CLANG_RESOURCE_DIR" \
    -Xcc -isystem"$SDKROOT/usr/include" \
    -Xcc -isystem"$SDKROOT/System/Library/Frameworks" \
    -Xcc -iframework"$SDKROOT/System/Library/Frameworks" \
    -Xcc -iframework"$SDKROOT/Library/Frameworks" \
    -Xcc -F"$SDKROOT/System/Library/Frameworks" \
    -Xcc -F"$SDKROOT/Library/Frameworks" \
    -Xcc -isysroot"$SDKROOT" \
    -Xswiftc -sdk -Xswiftc "$SDKROOT" \
    -Xswiftc -module-cache-path -Xswiftc "$MODULE_CACHE_DIR"

# Check if build succeeded
if [ $? -ne 0 ]; then
    echo "❌ Build Failed!"
    exit 1
fi

APP_EXECUTABLE="TemporaryAI"
APP_DISPLAY_NAME="Temporary AI"
BUILD_DIR=".build/release"
OUTPUT_DIR="build"
APP_BUNDLE="${OUTPUT_DIR}/${APP_DISPLAY_NAME}.app"

rm -rf  "$APP_BUNDLE" # Clean previous app bundle if exists
# 3. Assemble App Bundle
echo "📦 Packaging $APP_BUNDLE..."
mkdir -p "$OUTPUT_DIR"
rm -rf "$APP_BUNDLE" # Clean previous build
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Binary and Icon
# Note: The binary name inside MacOS/ MUST match CFBundleExecutable in Info.plist
cp "$BUILD_DIR/$APP_EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE"
cp "$ICON_DEST" "$APP_BUNDLE/Contents/Resources/"

# Copy Resource Bundle (Required for Bundle.module)
if [ -d "$BUILD_DIR/TemporaryAI_TemporaryAI.bundle" ]; then
    cp -r "$BUILD_DIR/TemporaryAI_TemporaryAI.bundle" "$APP_BUNDLE/Contents/Resources/"
    echo "✅ Copied Resource Bundle."
else
    echo "⚠️ Warning: Resource bundle not found at $BUILD_DIR/TemporaryAI_TemporaryAI.bundle"
fi

# Write Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.TemporaryAI</string>
    <key>CFBundleName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_DISPLAY_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF

echo "✅ App bundle created successfully at ./$APP_BUNDLE"
