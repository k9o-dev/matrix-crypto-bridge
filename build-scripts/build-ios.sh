#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
RUST_DIR="$PROJECT_ROOT/fortress-crypto-core"
IOS_DIR="$PROJECT_ROOT/fortress-crypto-ios"
BUILD_DIR="$IOS_DIR/build"

echo -e "${GREEN}Matrix Crypto Bridge - iOS Build Script${NC}"
echo "Project root: $PROJECT_ROOT"
echo "Rust dir: $RUST_DIR"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: Xcode is not installed${NC}"
    echo "Install Xcode from App Store or https://developer.apple.com/download/"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n1)
echo -e "${GREEN}✓ $XCODE_VERSION${NC}"

# Check if Rust is installed
if ! command -v rustc &> /dev/null; then
    echo -e "${RED}Error: Rust is not installed${NC}"
    exit 1
fi

# Check if uniffi-bindgen is installed
if ! command -v uniffi-bindgen &> /dev/null; then
    echo -e "${YELLOW}Installing uniffi with CLI support...${NC}"
    cargo install uniffi --features=cli
fi

# Ensure iOS targets are installed
echo ""
echo -e "${YELLOW}Ensuring iOS Rust targets are installed...${NC}"
rustup target add aarch64-apple-ios x86_64-apple-ios

# Build Rust for iOS
echo ""
echo -e "${YELLOW}Building Rust for iOS...${NC}"

cd "$RUST_DIR"

echo "Building for aarch64-apple-ios (device)..."
if ! cargo build --release --target aarch64-apple-ios; then
    echo -e "${RED}✗ Failed to build for aarch64-apple-ios${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Built for aarch64-apple-ios${NC}"

echo ""
echo "Building for x86_64-apple-ios (simulator)..."
if ! cargo build --release --target x86_64-apple-ios; then
    echo -e "${RED}✗ Failed to build for x86_64-apple-ios${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Built for x86_64-apple-ios${NC}"

# Create build directory
mkdir -p "$BUILD_DIR"

# Generate Swift bindings
echo ""
echo -e "${YELLOW}Generating Swift bindings...${NC}"
if ! uniffi-bindgen generate \
    "$RUST_DIR/src/matrix_crypto.udl" \
    --language swift \
    --out-dir "$IOS_DIR/generated"; then
    echo -e "${RED}✗ Failed to generate Swift bindings${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Generated Swift bindings${NC}"

# Create universal library (lipo)
echo ""
echo -e "${YELLOW}Creating universal library...${NC}"

# Use the workspace target directory (one level up from fortress-crypto-core)
WORKSPACE_TARGET="$PROJECT_ROOT/target"
DEVICE_LIB="$WORKSPACE_TARGET/aarch64-apple-ios/release/libmatrix_crypto_core.a"
SIMULATOR_LIB="$WORKSPACE_TARGET/x86_64-apple-ios/release/libmatrix_crypto_core.a"
UNIVERSAL_LIB="$BUILD_DIR/libmatrix_crypto_core.a"

echo "Looking for device library: $DEVICE_LIB"
if [ ! -f "$DEVICE_LIB" ]; then
    echo -e "${RED}✗ Device library not found: $DEVICE_LIB${NC}"
    echo "Available files in target/aarch64-apple-ios/release/:"
    ls -la "$WORKSPACE_TARGET/aarch64-apple-ios/release/" 2>/dev/null || echo "Directory not found"
    exit 1
fi

echo "Looking for simulator library: $SIMULATOR_LIB"
if [ ! -f "$SIMULATOR_LIB" ]; then
    echo -e "${RED}✗ Simulator library not found: $SIMULATOR_LIB${NC}"
    echo "Available files in target/x86_64-apple-ios/release/:"
    ls -la "$WORKSPACE_TARGET/x86_64-apple-ios/release/" 2>/dev/null || echo "Directory not found"
    exit 1
fi

echo "Creating universal library from:"
echo "  Device:    $DEVICE_LIB"
echo "  Simulator: $SIMULATOR_LIB"

lipo -create "$DEVICE_LIB" "$SIMULATOR_LIB" -output "$UNIVERSAL_LIB"
echo -e "${GREEN}✓ Created universal library: $UNIVERSAL_LIB${NC}"

# Create XCFramework using xcodebuild
echo ""
echo -e "${YELLOW}Creating XCFramework...${NC}"

XCFRAMEWORK_PATH="$BUILD_DIR/MatrixCryptoBridge.xcframework"

# Remove existing framework if it exists
if [ -d "$XCFRAMEWORK_PATH" ]; then
    rm -rf "$XCFRAMEWORK_PATH"
fi

# Create temporary framework directories for xcodebuild
# Note: xcodebuild expects the framework name to match the binary name
TEMP_FRAMEWORK_DEVICE="$BUILD_DIR/temp/device/MatrixCryptoBridge.framework"
TEMP_FRAMEWORK_SIMULATOR="$BUILD_DIR/temp/simulator/MatrixCryptoBridge.framework"

mkdir -p "$BUILD_DIR/temp"
mkdir -p "$TEMP_FRAMEWORK_DEVICE/Headers"
mkdir -p "$TEMP_FRAMEWORK_SIMULATOR/Headers"

# Copy device library
cp "$DEVICE_LIB" "$TEMP_FRAMEWORK_DEVICE/MatrixCryptoBridge"

# Copy simulator library
cp "$SIMULATOR_LIB" "$TEMP_FRAMEWORK_SIMULATOR/MatrixCryptoBridge"

# Create Info.plist for device framework
cat > "$TEMP_FRAMEWORK_DEVICE/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MatrixCryptoBridge</string>
    <key>CFBundleIdentifier</key>
    <string>com.matrix.crypto.bridge</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MatrixCryptoBridge</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>12.0</string>
</dict>
</plist>
EOF

# Create Info.plist for simulator framework
cp "$TEMP_FRAMEWORK_DEVICE/Info.plist" "$TEMP_FRAMEWORK_SIMULATOR/Info.plist"

# Create module.modulemap for both frameworks
mkdir -p "$TEMP_FRAMEWORK_DEVICE/Modules"
mkdir -p "$TEMP_FRAMEWORK_SIMULATOR/Modules"

cat > "$TEMP_FRAMEWORK_DEVICE/Modules/module.modulemap" << 'EOF'
framework module MatrixCryptoBridge {
    umbrella header "MatrixCryptoBridge.h"
    export *
    module * { export * }
}
EOF

cp "$TEMP_FRAMEWORK_DEVICE/Modules/module.modulemap" "$TEMP_FRAMEWORK_SIMULATOR/Modules/module.modulemap"

# Create empty header files
touch "$TEMP_FRAMEWORK_DEVICE/Headers/MatrixCryptoBridge.h"
touch "$TEMP_FRAMEWORK_SIMULATOR/Headers/MatrixCryptoBridge.h"

# Create XCFramework
if ! xcodebuild -create-xcframework \
    -framework "$TEMP_FRAMEWORK_DEVICE" \
    -framework "$TEMP_FRAMEWORK_SIMULATOR" \
    -output "$XCFRAMEWORK_PATH"; then
    echo -e "${RED}✗ Failed to create XCFramework${NC}"
    echo "Cleaning up temporary files..."
    rm -rf "$BUILD_DIR/temp"
    exit 1
fi

# Verify XCFramework was created
if [ ! -d "$XCFRAMEWORK_PATH" ]; then
    echo -e "${RED}✗ XCFramework not found at: $XCFRAMEWORK_PATH${NC}"
    rm -rf "$BUILD_DIR/temp"
    exit 1
fi

echo -e "${GREEN}✓ Created XCFramework${NC}"

# Cleanup temporary frameworks
rm -rf "$BUILD_DIR/temp"

echo ""
echo -e "${GREEN}✓ iOS build complete!${NC}"
echo ""
echo -e "${BLUE}Build artifacts:${NC}"
echo "  XCFramework: $XCFRAMEWORK_PATH"
echo "  Universal lib: $UNIVERSAL_LIB"
echo "  Swift bindings: $IOS_DIR/generated/"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Copy XCFramework to your Xcode project"
echo "  2. Link MatrixCryptoBridge in Build Phases"
echo "  3. Import in Swift: import MatrixCryptoBridge"
