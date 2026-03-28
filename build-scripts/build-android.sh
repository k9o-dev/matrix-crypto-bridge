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
WORKSPACE_TARGET="$PROJECT_ROOT/target"

echo -e "${GREEN}Matrix Crypto Bridge - Android Build Script${NC}"
echo "Project root: $PROJECT_ROOT"
echo "Rust dir: $RUST_DIR"
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

# Create Cargo config for cross-compilation
echo ""
echo -e "${YELLOW}Setting up Cargo configuration for cross-compilation...${NC}"

CARGO_CONFIG_DIR="$RUST_DIR/.cargo"
mkdir -p "$CARGO_CONFIG_DIR"

# Create cargo config with proper cross-compilation settings
cat > "$CARGO_CONFIG_DIR/config.toml" << EOF
[build]
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

[target.aarch64-linux-android]
ar = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${HOST_PLATFORM}-x86_64/bin/llvm-ar"
linker = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${HOST_PLATFORM}-x86_64/bin/aarch64-linux-android21-clang"
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

[target.armv7-linux-androideabi]
ar = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${HOST_PLATFORM}-x86_64/bin/llvm-ar"
linker = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${HOST_PLATFORM}-x86_64/bin/armv7a-linux-androideabi21-clang"
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

[target.x86_64-linux-android]
ar = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${HOST_PLATFORM}-x86_64/bin/llvm-ar"
linker = "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/${HOST_PLATFORM}-x86_64/bin/x86_64-linux-android21-clang"
rustflags = ["-C", "link-arg=-fuse-ld=lld"]
EOF

echo -e "${GREEN}✓ Cargo configuration created${NC}"

# Build for each Android target
echo ""
echo -e "${YELLOW}Building Rust for Android...${NC}"

cd "$RUST_DIR"

# Function to build for a target
build_android_target() {
    local target=$1
    local arch_name=$2
    
    echo ""
    echo "Building for $target..."
    
    # Build with cargo
    if ! cargo build --release --target "$target"; then
        echo -e "${RED}✗ Failed to build for $target${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Built for $target${NC}"
    return 0
}

# Build for each target
build_android_target "aarch64-linux-android" "arm64-v8a" || exit 1
build_android_target "armv7-linux-androideabi" "armeabi-v7a" || exit 1
build_android_target "x86_64-linux-android" "x86_64" || exit 1

# Generate Kotlin bindings
echo ""
echo -e "${YELLOW}Generating Kotlin bindings...${NC}"

if command -v uniffi-bindgen &> /dev/null; then
    if uniffi-bindgen generate \
        "$RUST_DIR/src/matrix_crypto.udl" \
        --language kotlin \
        --no-format \
        --out-dir "$ANDROID_DIR/generated"; then
        echo -e "${GREEN}✓ Generated Kotlin bindings${NC}"
    else
        echo -e "${YELLOW}⚠ Kotlin binding generation had issues${NC}"
    fi
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

echo "Copying aarch64 library..."
if [ -f "$WORKSPACE_TARGET/aarch64-linux-android/release/libmatrix_crypto_core.so" ]; then
    cp "$WORKSPACE_TARGET/aarch64-linux-android/release/libmatrix_crypto_core.so" \
       "$ANDROID_DIR/src/main/jniLibs/arm64-v8a/"
    echo -e "${GREEN}✓ Copied arm64-v8a library${NC}"
else
    echo -e "${RED}✗ arm64-v8a library not found${NC}"
    echo "Looking for: $WORKSPACE_TARGET/aarch64-linux-android/release/libmatrix_crypto_core.so"
    exit 1
fi

echo "Copying armv7 library..."
if [ -f "$WORKSPACE_TARGET/armv7-linux-androideabi/release/libmatrix_crypto_core.so" ]; then
    cp "$WORKSPACE_TARGET/armv7-linux-androideabi/release/libmatrix_crypto_core.so" \
       "$ANDROID_DIR/src/main/jniLibs/armeabi-v7a/"
    echo -e "${GREEN}✓ Copied armeabi-v7a library${NC}"
else
    echo -e "${RED}✗ armeabi-v7a library not found${NC}"
    exit 1
fi

echo "Copying x86_64 library..."
if [ -f "$WORKSPACE_TARGET/x86_64-linux-android/release/libmatrix_crypto_core.so" ]; then
    cp "$WORKSPACE_TARGET/x86_64-linux-android/release/libmatrix_crypto_core.so" \
       "$ANDROID_DIR/src/main/jniLibs/x86_64/"
    echo -e "${GREEN}✓ Copied x86_64 library${NC}"
else
    echo -e "${RED}✗ x86_64 library not found${NC}"
    exit 1
fi

# Build Android AAR (optional - Gradle is not required for development)
echo ""
echo -e "${YELLOW}Android build complete!${NC}"
echo ""
echo -e "${BLUE}Build artifacts:${NC}"

# Check and report built libraries
for target in "${ANDROID_TARGETS[@]}"; do
    lib_path="$WORKSPACE_TARGET/$target/release/libmatrix_crypto_core.so"
    if [ -f "$lib_path" ]; then
        size=$(du -h "$lib_path" | cut -f1)
        echo "  - $target: $size"
    fi
done

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Libraries are ready in matrix-crypto-android/src/main/jniLibs/"
echo "  2. Open Android Studio"
echo "  3. Import matrix-crypto-android module"
echo "  4. Build the project (Gradle will package the .so files into AAR)"
echo "  5. Link in your React Native app"
echo ""
echo -e "${BLUE}Optional: Build AAR with Gradle${NC}"
echo "  If you want to build the AAR file locally:"
echo "  1. Install Gradle: brew install gradle (macOS) or download from gradle.org"
echo "  2. Run: cd matrix-crypto-android && gradle build"
echo "  3. AAR file will be in: matrix-crypto-android/build/outputs/aar/"
