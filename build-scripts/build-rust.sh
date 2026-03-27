#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
RUST_DIR="$PROJECT_ROOT/matrix-crypto-core"

echo -e "${GREEN}Matrix Crypto Bridge - Rust Build Script${NC}"
echo "Project root: $PROJECT_ROOT"
echo ""

# Check if Rust is installed
if ! command -v rustc &> /dev/null; then
    echo -e "${RED}Error: Rust is not installed${NC}"
    echo "Install Rust from https://rustup.rs/"
    exit 1
fi

# Get Rust version
RUST_VERSION=$(rustc --version)
echo -e "${GREEN}✓ $RUST_VERSION${NC}"

# Check if cargo is available
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: cargo is not installed${NC}"
    exit 1
fi

cd "$RUST_DIR"

# Determine which targets to build
TARGETS=()
BUILD_IOS=false
BUILD_ANDROID=false
BUILD_ALL=false

if [ "$1" == "ios" ]; then
    BUILD_IOS=true
    TARGETS=("aarch64-apple-ios" "x86_64-apple-ios")
elif [ "$1" == "android" ]; then
    BUILD_ANDROID=true
    TARGETS=("aarch64-linux-android" "armv7-linux-android" "x86_64-linux-android")
elif [ "$1" == "all" ] || [ -z "$1" ]; then
    BUILD_ALL=true
    TARGETS=("aarch64-apple-ios" "x86_64-apple-ios" "aarch64-linux-android" "armv7-linux-android" "x86_64-linux-android")
else
    echo -e "${RED}Usage: $0 [ios|android|all]${NC}"
    exit 1
fi

# Install targets if needed
echo ""
echo -e "${YELLOW}Installing Rust targets...${NC}"
for target in "${TARGETS[@]}"; do
    if ! rustup target list | grep -q "^$target (installed)"; then
        echo "Installing $target..."
        rustup target add "$target"
    else
        echo "✓ $target already installed"
    fi
done

# Build for each target
echo ""
echo -e "${YELLOW}Building Rust library...${NC}"

for target in "${TARGETS[@]}"; do
    echo ""
    echo "Building for $target..."
    cargo build --release --target "$target" 2>&1 | grep -E "Compiling|Finished|error|warning" || true
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Built for $target${NC}"
    else
        echo -e "${RED}✗ Failed to build for $target${NC}"
        exit 1
    fi
done

echo ""
echo -e "${GREEN}✓ Rust build complete!${NC}"
echo ""
echo "Build artifacts:"
for target in "${TARGETS[@]}"; do
    lib_path="target/$target/release/libmatrix_crypto_core.a"
    if [ -f "$lib_path" ]; then
        size=$(du -h "$lib_path" | cut -f1)
        echo "  - $target: $size"
    fi
done

echo ""
echo "Next steps:"
if [ "$BUILD_IOS" = true ] || [ "$BUILD_ALL" = true ]; then
    echo "  iOS:     ./build-scripts/build-ios.sh"
fi
if [ "$BUILD_ANDROID" = true ] || [ "$BUILD_ALL" = true ]; then
    echo "  Android: ./build-scripts/build-android.sh"
fi
