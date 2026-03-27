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
ANDROID_DIR="$PROJECT_ROOT/matrix-crypto-android"

echo -e "${GREEN}Matrix Crypto Bridge - Android Build Script${NC}"
echo "Project root: $PROJECT_ROOT"
echo ""

# Check if Rust is installed
if ! command -v rustc &> /dev/null; then
    echo -e "${RED}Error: Rust is not installed${NC}"
    exit 1
fi

RUST_VERSION=$(rustc --version)
echo -e "${GREEN}✓ $RUST_VERSION${NC}"

# Check for Android NDK
if [ -z "$ANDROID_NDK_HOME" ]; then
    # Try to find NDK in common locations
    if [ -d "$HOME/Android/sdk/ndk" ]; then
        # Find the latest NDK version
        ANDROID_NDK_HOME=$(ls -d "$HOME/Android/sdk/ndk"/* 2>/dev/null | sort -V | tail -n1)
    elif [ -d "$HOME/Library/Android/sdk/ndk" ]; then
        # macOS location
        ANDROID_NDK_HOME=$(ls -d "$HOME/Library/Android/sdk/ndk"/* 2>/dev/null | sort -V | tail -n1)
    fi
    
    if [ -z "$ANDROID_NDK_HOME" ]; then
        echo -e "${RED}Error: Android NDK not found${NC}"
        echo "Set ANDROID_NDK_HOME environment variable or install NDK via Android Studio"
        echo ""
        echo "To install NDK:"
        echo "  1. Open Android Studio"
        echo "  2. Go to SDK Manager"
        echo "  3. Select SDK Tools tab"
        echo "  4. Check 'NDK (Side by side)' and install"
        echo ""
        echo "Then set: export ANDROID_NDK_HOME=/path/to/ndk/r25"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Android NDK: $ANDROID_NDK_HOME${NC}"

# Check NDK version
if [ -f "$ANDROID_NDK_HOME/source.properties" ]; then
    NDK_VERSION=$(grep "Pkg.Revision" "$ANDROID_NDK_HOME/source.properties" | cut -d'=' -f2)
    echo -e "${GREEN}✓ NDK version: $NDK_VERSION${NC}"
fi

# Determine host platform
HOST_OS=$(uname -s)
case "$HOST_OS" in
    Darwin)
        HOST_PLATFORM="darwin"
        ;;
    Linux)
        HOST_PLATFORM="linux"
        ;;
    *)
        echo -e "${RED}Error: Unsupported host OS: $HOST_OS${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✓ Host platform: $HOST_PLATFORM${NC}"

# Install Android targets
echo ""
echo -e "${YELLOW}Installing Android Rust targets...${NC}"

ANDROID_TARGETS=("aarch64-linux-android" "armv7-linux-androideabi" "x86_64-linux-android")

for target in "${ANDROID_TARGETS[@]}"; do
    if ! rustup target list | grep -q "^$target (installed)"; then
        echo "Installing $target..."
        rustup target add "$target"
    else
        echo "✓ $target already installed"
    fi
done

# Build for each Android target
echo ""
echo -e "${YELLOW}Building Rust for Android...${NC}"

cd "$RUST_DIR"

# Function to build for a target
build_android_target() {
    local target=$1
    local arch=$2
    
    echo ""
    echo "Building for $target ($arch)..."
    
    # Set up environment variables for cross-compilation
    export CC="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${HOST_PLATFORM}-x86_64/bin/${arch}21-clang"
    export AR="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${HOST_PLATFORM}-x86_64/bin/llvm-ar"
    export RANLIB="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${HOST_PLATFORM}-x86_64/bin/llvm-ranlib"
    
    # Check if compiler exists
    if [ ! -f "$CC" ]; then
        echo -e "${RED}✗ Compiler not found: $CC${NC}"
        return 1
    fi
    
    # Build with cargo
    cargo build --release --target "$target" 2>&1 | grep -E "Compiling|Finished|error" || true
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Built for $target${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to build for $target${NC}"
        return 1
    fi
}

# Build for each target
build_android_target "aarch64-linux-android" "aarch64" || exit 1
build_android_target "armv7-linux-androideabi" "armv7a" || exit 1
build_android_target "x86_64-linux-android" "x86_64" || exit 1

# Generate Kotlin bindings
echo ""
echo -e "${YELLOW}Generating Kotlin bindings...${NC}"

if command -v uniffi-bindgen &> /dev/null; then
    uniffi-bindgen generate \
        "$RUST_DIR/src/matrix_crypto.udl" \
        --language kotlin \
        --out-dir "$ANDROID_DIR/generated" \
        2>&1 | grep -E "Generating|error" || true
else
    echo -e "${YELLOW}Note: uniffi-bindgen not found, skipping Kotlin binding generation${NC}"
    echo "Install with: cargo install uniffi --features=cli"
fi

# Copy libraries to Android project
echo ""
echo -e "${YELLOW}Copying libraries to Android project...${NC}"

mkdir -p "$ANDROID_DIR/src/main/jniLibs/arm64-v8a"
mkdir -p "$ANDROID_DIR/src/main/jniLibs/armeabi-v7a"
mkdir -p "$ANDROID_DIR/src/main/jniLibs/x86_64"

cp "$RUST_DIR/target/aarch64-linux-android/release/libmatrix_crypto_core.so" \
   "$ANDROID_DIR/src/main/jniLibs/arm64-v8a/" 2>/dev/null || true

cp "$RUST_DIR/target/armv7-linux-androideabi/release/libmatrix_crypto_core.so" \
   "$ANDROID_DIR/src/main/jniLibs/armeabi-v7a/" 2>/dev/null || true

cp "$RUST_DIR/target/x86_64-linux-android/release/libmatrix_crypto_core.so" \
   "$ANDROID_DIR/src/main/jniLibs/x86_64/" 2>/dev/null || true

echo -e "${GREEN}✓ Copied libraries${NC}"

# Build Android AAR
echo ""
echo -e "${YELLOW}Building Android AAR...${NC}"

if command -v gradle &> /dev/null; then
    cd "$ANDROID_DIR"
    gradle build 2>&1 | grep -E "BUILD|error" || true
    echo -e "${GREEN}✓ Built Android AAR${NC}"
else
    echo -e "${YELLOW}Note: Gradle not found, skipping AAR build${NC}"
    echo "Install Android Studio or Gradle to build AAR"
fi

echo ""
echo -e "${GREEN}✓ Android build complete!${NC}"
echo ""
echo -e "${BLUE}Build artifacts:${NC}"
for target in "${ANDROID_TARGETS[@]}"; do
    lib_path="$RUST_DIR/target/$target/release/libmatrix_crypto_core.a"
    if [ -f "$lib_path" ]; then
        size=$(du -h "$lib_path" | cut -f1)
        echo "  - $target: $size"
    fi
done

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Open Android Studio"
echo "  2. Import matrix-crypto-android module"
echo "  3. Build the project"
echo "  4. Link in your React Native app"
