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
RUST_DIR="$PROJECT_ROOT/matrix-crypto-core"
IOS_DIR="$PROJECT_ROOT/matrix-crypto-ios"
BUILD_DIR="$IOS_DIR/build"

echo -e "${GREEN}Matrix Crypto Bridge - iOS Build Script${NC}"
echo "Project root: $PROJECT_ROOT"
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
    echo -e "${YELLOW}Installing uniffi-bindgen...${NC}"
    cargo install uniffi_bindgen
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
cargo build --release --target aarch64-apple-ios 2>&1 | grep -E "Compiling|Finished|error" || true

echo "Building for x86_64-apple-ios (simulator)..."
cargo build --release --target x86_64-apple-ios 2>&1 | grep -E "Compiling|Finished|error" || true

# Create build directory
mkdir -p "$BUILD_DIR"

# Generate Swift bindings
echo ""
echo -e "${YELLOW}Generating Swift bindings...${NC}"
uniffi-bindgen generate \
    "$RUST_DIR/src/lib.rs" \
    --language swift \
    --out-dir "$IOS_DIR/generated" \
    2>&1 | grep -E "Generating|error" || true

# Create universal library (lipo)
echo ""
echo -e "${YELLOW}Creating universal library...${NC}"

DEVICE_LIB="$RUST_DIR/target/aarch64-apple-ios/release/libmatrix_crypto_core.a"
SIMULATOR_LIB="$RUST_DIR/target/x86_64-apple-ios/release/libmatrix_crypto_core.a"
UNIVERSAL_LIB="$BUILD_DIR/libmatrix_crypto_core.a"

if [ -f "$DEVICE_LIB" ] && [ -f "$SIMULATOR_LIB" ]; then
    lipo -create "$DEVICE_LIB" "$SIMULATOR_LIB" -output "$UNIVERSAL_LIB"
    echo -e "${GREEN}✓ Created universal library${NC}"
else
    echo -e "${RED}✗ Could not find compiled libraries${NC}"
    exit 1
fi

# Create XCFramework
echo ""
echo -e "${YELLOW}Creating XCFramework...${NC}"

XCFRAMEWORK_PATH="$BUILD_DIR/MatrixCryptoBridge.xcframework"

# Remove existing framework if it exists
if [ -d "$XCFRAMEWORK_PATH" ]; then
    rm -rf "$XCFRAMEWORK_PATH"
fi

# Create framework directories
FRAMEWORK_DIR_DEVICE="$BUILD_DIR/MatrixCryptoBridge-device.framework"
FRAMEWORK_DIR_SIMULATOR="$BUILD_DIR/MatrixCryptoBridge-simulator.framework"

mkdir -p "$FRAMEWORK_DIR_DEVICE/Headers"
mkdir -p "$FRAMEWORK_DIR_SIMULATOR/Headers"

# Copy libraries
cp "$DEVICE_LIB" "$FRAMEWORK_DIR_DEVICE/MatrixCryptoBridge"
cp "$SIMULATOR_LIB" "$FRAMEWORK_DIR_SIMULATOR/MatrixCryptoBridge"

# Create module maps
cat > "$FRAMEWORK_DIR_DEVICE/Modules/module.modulemap" << 'EOF'
framework module MatrixCryptoBridge {
    header "MatrixCryptoBridge.h"
    export *
}
EOF

cat > "$FRAMEWORK_DIR_SIMULATOR/Modules/module.modulemap" << 'EOF'
framework module MatrixCryptoBridge {
    header "MatrixCryptoBridge.h"
    export *
}
EOF

# Create XCFramework
xcodebuild -create-xcframework \
    -framework "$FRAMEWORK_DIR_DEVICE" \
    -framework "$FRAMEWORK_DIR_SIMULATOR" \
    -output "$XCFRAMEWORK_PATH" \
    2>&1 | grep -E "Creating|error" || true

if [ -d "$XCFRAMEWORK_PATH" ]; then
    echo -e "${GREEN}✓ Created XCFramework${NC}"
else
    echo -e "${RED}✗ Failed to create XCFramework${NC}"
    exit 1
fi

# Cleanup temporary frameworks
rm -rf "$FRAMEWORK_DIR_DEVICE" "$FRAMEWORK_DIR_SIMULATOR"

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
