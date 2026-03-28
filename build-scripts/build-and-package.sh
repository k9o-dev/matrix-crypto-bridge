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
PACKAGE_DIR="$PROJECT_ROOT/react-native-matrix-crypto"
WORKSPACE_TARGET="$PROJECT_ROOT/target"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Matrix Crypto Bridge - Build & Package Script            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Determine which platforms to build
BUILD_IOS=false
BUILD_ANDROID=false
BUILD_ALL=false

if [ "$1" == "ios" ]; then
    BUILD_IOS=true
elif [ "$1" == "android" ]; then
    BUILD_ANDROID=true
elif [ "$1" == "all" ] || [ -z "$1" ]; then
    BUILD_ALL=true
else
    echo -e "${RED}Usage: $0 [ios|android|all]${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 ios       # Build and package for iOS only"
    echo "  $0 android   # Build and package for Android only"
    echo "  $0 all       # Build and package for all platforms (default)"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to print section header
print_section() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================

print_section "Checking Prerequisites"

if ! command_exists rustc; then
    print_error "Rust is not installed"
    echo "Install from: https://rustup.rs/"
    exit 1
fi
print_success "Rust installed: $(rustc --version)"

if ! command_exists cargo; then
    print_error "Cargo is not installed"
    exit 1
fi
print_success "Cargo available"

# ============================================================================
# iOS BUILD
# ============================================================================

if [ "$BUILD_IOS" = true ] || [ "$BUILD_ALL" = true ]; then
    print_section "Building for iOS"
    
    cd "$RUST_DIR"
    
    # iOS targets
    IOS_TARGETS=("aarch64-apple-ios" "x86_64-apple-ios")
    
    # Install targets
    echo -e "${YELLOW}Installing iOS targets...${NC}"
    for target in "${IOS_TARGETS[@]}"; do
        if ! rustup target list | grep -q "^$target (installed)"; then
            echo "Installing $target..."
            rustup target add "$target"
        else
            print_success "$target already installed"
        fi
    done
    
    # Build for each iOS target
    echo ""
    echo -e "${YELLOW}Building Rust libraries for iOS...${NC}"
    for target in "${IOS_TARGETS[@]}"; do
        echo ""
        echo "Building for $target..."
        if cargo build --release --target "$target"; then
            print_success "Built for $target"
        else
            print_error "Failed to build for $target"
            exit 1
        fi
    done
    
    # Create iOS prebuilt directory
    print_section "Packaging iOS Libraries"
    
    mkdir -p "$PACKAGE_DIR/ios/prebuilt"
    
    echo "Copying aarch64 (device) library..."
    if [ -f "$WORKSPACE_TARGET/aarch64-apple-ios/release/libmatrix_crypto_core.a" ]; then
        cp "$WORKSPACE_TARGET/aarch64-apple-ios/release/libmatrix_crypto_core.a" \
           "$PACKAGE_DIR/ios/prebuilt/libmatrix_crypto_core_arm64.a"
        print_success "Copied arm64 library"
    else
        print_error "arm64 library not found"
        exit 1
    fi
    
    echo "Copying x86_64 (simulator) library..."
    if [ -f "$WORKSPACE_TARGET/x86_64-apple-ios/release/libmatrix_crypto_core.a" ]; then
        cp "$WORKSPACE_TARGET/x86_64-apple-ios/release/libmatrix_crypto_core.a" \
           "$PACKAGE_DIR/ios/prebuilt/libmatrix_crypto_core_sim.a"
        print_success "Copied simulator library"
    else
        print_error "Simulator library not found"
        exit 1
    fi
    
    # Report iOS artifacts
    echo ""
    echo -e "${BLUE}iOS Build Artifacts:${NC}"
    for lib in "$PACKAGE_DIR/ios/prebuilt"/*.a; do
        if [ -f "$lib" ]; then
            size=$(du -h "$lib" | cut -f1)
            echo "  - $(basename "$lib"): $size"
        fi
    done
fi

# ============================================================================
# ANDROID BUILD
# ============================================================================

if [ "$BUILD_ANDROID" = true ] || [ "$BUILD_ALL" = true ]; then
    print_section "Building for Android"
    
    # Run the Android build script
    if [ -f "$SCRIPT_DIR/build-android.sh" ]; then
        bash "$SCRIPT_DIR/build-android.sh"
    else
        print_error "build-android.sh not found"
        exit 1
    fi
    
    # Copy Android libraries to package
    print_section "Packaging Android Libraries"
    
    mkdir -p "$PACKAGE_DIR/android/src/main/jniLibs/arm64-v8a"
    mkdir -p "$PACKAGE_DIR/android/src/main/jniLibs/armeabi-v7a"
    mkdir -p "$PACKAGE_DIR/android/src/main/jniLibs/x86_64"
    
    echo "Copying aarch64 library..."
    if [ -f "$WORKSPACE_TARGET/aarch64-linux-android/release/libmatrix_crypto_core.so" ]; then
        cp "$WORKSPACE_TARGET/aarch64-linux-android/release/libmatrix_crypto_core.so" \
           "$PACKAGE_DIR/android/src/main/jniLibs/arm64-v8a/"
        print_success "Copied arm64-v8a library"
    else
        print_error "arm64-v8a library not found"
        exit 1
    fi
    
    echo "Copying armv7 library..."
    if [ -f "$WORKSPACE_TARGET/armv7-linux-androideabi/release/libmatrix_crypto_core.so" ]; then
        cp "$WORKSPACE_TARGET/armv7-linux-androideabi/release/libmatrix_crypto_core.so" \
           "$PACKAGE_DIR/android/src/main/jniLibs/armeabi-v7a/"
        print_success "Copied armeabi-v7a library"
    else
        print_error "armeabi-v7a library not found"
        exit 1
    fi
    
    echo "Copying x86_64 library..."
    if [ -f "$WORKSPACE_TARGET/x86_64-linux-android/release/libmatrix_crypto_core.so" ]; then
        cp "$WORKSPACE_TARGET/x86_64-linux-android/release/libmatrix_crypto_core.so" \
           "$PACKAGE_DIR/android/src/main/jniLibs/x86_64/"
        print_success "Copied x86_64 library"
    else
        print_error "x86_64 library not found"
        exit 1
    fi
    
    # Report Android artifacts
    echo ""
    echo -e "${BLUE}Android Build Artifacts:${NC}"
    for arch_dir in "$PACKAGE_DIR/android/src/main/jniLibs"/*; do
        if [ -d "$arch_dir" ]; then
            arch=$(basename "$arch_dir")
            lib_file="$arch_dir/libmatrix_crypto_core.so"
            if [ -f "$lib_file" ]; then
                size=$(du -h "$lib_file" | cut -f1)
                echo "  - $arch: $size"
            fi
        fi
    done
fi

# ============================================================================
# PACKAGE SUMMARY
# ============================================================================

print_section "Build & Package Summary"

echo -e "${BLUE}Package Directory:${NC} $PACKAGE_DIR"
echo ""

if [ "$BUILD_IOS" = true ] || [ "$BUILD_ALL" = true ]; then
    echo -e "${BLUE}iOS Libraries:${NC}"
    ls -lh "$PACKAGE_DIR/ios/prebuilt/" 2>/dev/null || echo "  (not found)"
    echo ""
fi

if [ "$BUILD_ANDROID" = true ] || [ "$BUILD_ALL" = true ]; then
    echo -e "${BLUE}Android Libraries:${NC}"
    find "$PACKAGE_DIR/android/src/main/jniLibs" -name "*.so" -exec ls -lh {} \; 2>/dev/null || echo "  (not found)"
    echo ""
fi

# ============================================================================
# NEXT STEPS
# ============================================================================

print_section "Next Steps"

echo -e "${BLUE}1. Verify package contents:${NC}"
echo "   ls -la $PACKAGE_DIR/"
echo ""

echo -e "${BLUE}2. Build TypeScript:${NC}"
echo "   cd $PACKAGE_DIR"
echo "   npm run build"
echo ""

echo -e "${BLUE}3. Test locally (optional):${NC}"
echo "   npm link"
echo "   cd /path/to/fortress"
echo "   npm link @k9o/react-native-matrix-crypto"
echo ""

echo -e "${BLUE}4. Publish to NPM:${NC}"
echo "   cd $PACKAGE_DIR"
echo "   npm publish --access public"
echo ""

print_success "Build and packaging complete!"
