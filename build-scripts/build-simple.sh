#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Parse arguments
BUILD_TARGET="${1:-all}"

case $BUILD_TARGET in
    ios)
        print_section "Building iOS Libraries (Simple)"
        
        echo "Building matrix-crypto-ios for aarch64-apple-ios (device)..."
        cd "$PROJECT_ROOT"
        cargo build -p matrix-crypto-ios --target aarch64-apple-ios --release --verbose 2>&1 | tail -20
        
        print_info "Checking what files were produced..."
        echo "Contents of target/aarch64-apple-ios/release/:"
        ls -lah "$WORKSPACE_TARGET/aarch64-apple-ios/release/" | grep -E "matrix_crypto|\.a|\.rlib|\.dylib" || echo "No matrix_crypto files found"
        
        echo -e "\nBuilding matrix-crypto-ios for x86_64-apple-ios (simulator)..."
        cargo build -p matrix-crypto-ios --target x86_64-apple-ios --release --verbose 2>&1 | tail -20
        
        print_info "Checking what files were produced..."
        echo "Contents of target/x86_64-apple-ios/release/:"
        ls -lah "$WORKSPACE_TARGET/x86_64-apple-ios/release/" | grep -E "matrix_crypto|\.a|\.rlib|\.dylib" || echo "No matrix_crypto files found"
        ;;
        
    android)
        print_section "Building Android Libraries (Simple)"
        
        for target in aarch64-linux-android armv7-linux-androideabi x86_64-linux-android; do
            echo "Building matrix-crypto-android for $target..."
            cd "$PROJECT_ROOT"
            cargo build -p matrix-crypto-android --target "$target" --release --verbose 2>&1 | tail -20
            
            print_info "Checking what files were produced..."
            echo "Contents of target/$target/release/:"
            ls -lah "$WORKSPACE_TARGET/$target/release/" | grep -E "matrix_crypto|\.so|\.a|\.rlib" || echo "No matrix_crypto files found"
        done
        ;;
        
    all)
        print_section "Building All Libraries (Simple)"
        echo "Building iOS..."
        "$SCRIPT_DIR/build-simple.sh" ios
        echo -e "\nBuilding Android..."
        "$SCRIPT_DIR/build-simple.sh" android
        ;;
        
    *)
        echo "Usage: $0 {ios|android|all}"
        exit 1
        ;;
esac

print_success "Build complete!"
