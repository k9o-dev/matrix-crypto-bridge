#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
WORKSPACE_TARGET="$PROJECT_ROOT/target"
PACKAGE_DIR="$PROJECT_ROOT/react-native-matrix-crypto"

print_section() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Parse arguments
BUILD_TARGET="${1:-all}"

case $BUILD_TARGET in
    ios)
        print_section "Building iOS Libraries (Workspace)"
        
        echo "Building for aarch64-apple-ios (device)..."
        cd "$PROJECT_ROOT"
        cargo build -p matrix-crypto-ios --target aarch64-apple-ios --release
        print_success "Built for aarch64-apple-ios"
        
        echo "Building for x86_64-apple-ios (simulator)..."
        cargo build -p matrix-crypto-ios --target x86_64-apple-ios --release
        print_success "Built for x86_64-apple-ios"
        
        # Copy libraries
        print_section "Packaging iOS Libraries"
        mkdir -p "$PACKAGE_DIR/ios/prebuilt"
        
        echo "Copying aarch64 (device) library..."
        if [ -f "$WORKSPACE_TARGET/aarch64-apple-ios/release/libmatrix_crypto_ios.a" ]; then
            cp "$WORKSPACE_TARGET/aarch64-apple-ios/release/libmatrix_crypto_ios.a" \
               "$PACKAGE_DIR/ios/prebuilt/libmatrix_crypto_core_arm64.a"
            print_success "Copied arm64 library"
        else
            print_error "arm64 library not found at $WORKSPACE_TARGET/aarch64-apple-ios/release/libmatrix_crypto_ios.a"
            exit 1
        fi
        
        echo "Copying x86_64 (simulator) library..."
        if [ -f "$WORKSPACE_TARGET/x86_64-apple-ios/release/libmatrix_crypto_ios.a" ]; then
            cp "$WORKSPACE_TARGET/x86_64-apple-ios/release/libmatrix_crypto_ios.a" \
               "$PACKAGE_DIR/ios/prebuilt/libmatrix_crypto_core_sim.a"
            print_success "Copied simulator library"
        else
            print_error "Simulator library not found at $WORKSPACE_TARGET/x86_64-apple-ios/release/libmatrix_crypto_ios.a"
            exit 1
        fi
        ;;
        
    android)
        print_section "Building Android Libraries (Workspace)"
        
        for target in aarch64-linux-android armv7-linux-androideabi x86_64-linux-android; do
            echo "Building for $target..."
            cd "$PROJECT_ROOT"
            cargo build -p matrix-crypto-android --target "$target" --release
            print_success "Built for $target"
        done
        
        # Copy libraries
        print_section "Packaging Android Libraries"
        mkdir -p "$PACKAGE_DIR/android/src/main/jniLibs/arm64-v8a"
        mkdir -p "$PACKAGE_DIR/android/src/main/jniLibs/armeabi-v7a"
        mkdir -p "$PACKAGE_DIR/android/src/main/jniLibs/x86_64"
        
        echo "Copying aarch64 library..."
        if [ -f "$WORKSPACE_TARGET/aarch64-linux-android/release/libmatrix_crypto_android.so" ]; then
            cp "$WORKSPACE_TARGET/aarch64-linux-android/release/libmatrix_crypto_android.so" \
               "$PACKAGE_DIR/android/src/main/jniLibs/arm64-v8a/"
            print_success "Copied arm64-v8a library (.so)"
        else
            print_error "arm64-v8a library not found at $WORKSPACE_TARGET/aarch64-linux-android/release/libmatrix_crypto_android.so"
            exit 1
        fi
        
        echo "Copying armv7 library..."
        if [ -f "$WORKSPACE_TARGET/armv7-linux-androideabi/release/libmatrix_crypto_android.so" ]; then
            cp "$WORKSPACE_TARGET/armv7-linux-androideabi/release/libmatrix_crypto_android.so" \
               "$PACKAGE_DIR/android/src/main/jniLibs/armeabi-v7a/"
            print_success "Copied armeabi-v7a library (.so)"
        else
            print_error "armeabi-v7a library not found at $WORKSPACE_TARGET/armv7-linux-androideabi/release/libmatrix_crypto_android.so"
            exit 1
        fi
        
        echo "Copying x86_64 library..."
        if [ -f "$WORKSPACE_TARGET/x86_64-linux-android/release/libmatrix_crypto_android.so" ]; then
            cp "$WORKSPACE_TARGET/x86_64-linux-android/release/libmatrix_crypto_android.so" \
               "$PACKAGE_DIR/android/src/main/jniLibs/x86_64/"
            print_success "Copied x86_64 library (.so)"
        else
            print_error "x86_64 library not found at $WORKSPACE_TARGET/x86_64-linux-android/release/libmatrix_crypto_android.so"
            exit 1
        fi
        ;;
        
    all)
        print_section "Building All Platforms (Workspace)"
        bash "$SCRIPT_DIR/build-workspace.sh" ios
        bash "$SCRIPT_DIR/build-workspace.sh" android
        print_section "All Builds Complete"
        ;;
        
    *)
        echo "Usage: $0 {ios|android|all}"
        exit 1
        ;;
esac

print_success "Build complete!"
