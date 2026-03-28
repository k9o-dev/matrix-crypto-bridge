#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
WORKSPACE_TARGET="$PROJECT_ROOT/target"
PACKAGE_DIR="$PROJECT_ROOT/react-native-matrix-crypto"
DIST_DIR="$PROJECT_ROOT/dist"
BUILD_TIMESTAMP=$(date +%Y%m%d_%H%M%S)

print_section() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

print_subsection() {
    echo -e "${CYAN}▶ $1${NC}"
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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to verify build artifacts
verify_artifact() {
    local file=$1
    local description=$2
    if [ -f "$file" ]; then
        local size=$(du -h "$file" | cut -f1)
        print_success "$description: $file ($size)"
        return 0
    else
        print_error "$description not found: $file"
        return 1
    fi
}

# Function to build iOS libraries
build_ios() {
    print_section "Building iOS Libraries"
    
    local ios_targets=("aarch64-apple-ios" "x86_64-apple-ios")
    local ios_output_dir="$DIST_DIR/ios"
    mkdir -p "$ios_output_dir"
    
    for target in "${ios_targets[@]}"; do
        print_subsection "Building for $target..."
        
        cd "$PROJECT_ROOT"
        if cargo build -p matrix-crypto-ios --target "$target" --release; then
            print_success "Build succeeded for $target"
            
            # Copy the static library
            local lib_file="$WORKSPACE_TARGET/$target/release/libmatrix_crypto_ios.a"
            if verify_artifact "$lib_file" "iOS static library ($target)"; then
                cp "$lib_file" "$ios_output_dir/libmatrix_crypto_ios_$target.a"
                print_success "Copied to $ios_output_dir/libmatrix_crypto_ios_$target.a"
            else
                print_error "Failed to find library for $target"
                return 1
            fi
        else
            print_error "Build failed for $target"
            return 1
        fi
    done
    
    # Create universal binary (lipo)
    if command_exists lipo; then
        print_subsection "Creating universal binary..."
        local universal_lib="$ios_output_dir/libmatrix_crypto_ios.a"
        lipo -create \
            "$ios_output_dir/libmatrix_crypto_ios_aarch64-apple-ios.a" \
            "$ios_output_dir/libmatrix_crypto_ios_x86_64-apple-ios.a" \
            -output "$universal_lib"
        
        if verify_artifact "$universal_lib" "Universal iOS library"; then
            print_success "Created universal binary"
        else
            print_warning "Failed to create universal binary"
        fi
    else
        print_warning "lipo not found - skipping universal binary creation (requires macOS)"
    fi
    
    # Also copy to react-native package for convenience
    print_subsection "Copying to react-native-matrix-crypto package..."
    mkdir -p "$PACKAGE_DIR/ios/prebuilt"
    cp "$ios_output_dir/libmatrix_crypto_ios_aarch64-apple-ios.a" "$PACKAGE_DIR/ios/prebuilt/libmatrix_crypto_core_arm64.a"
    cp "$ios_output_dir/libmatrix_crypto_ios_x86_64-apple-ios.a" "$PACKAGE_DIR/ios/prebuilt/libmatrix_crypto_core_sim.a"
    if [ -f "$ios_output_dir/libmatrix_crypto_ios.a" ]; then
        cp "$ios_output_dir/libmatrix_crypto_ios.a" "$PACKAGE_DIR/ios/prebuilt/libmatrix_crypto_ios.a"
    fi
    print_success "Copied to react-native package"
    
    return 0
}

# Function to build Android libraries
build_android() {
    print_section "Building Android Libraries"
    
    local android_targets=("aarch64-linux-android" "armv7-linux-androideabi" "x86_64-linux-android")
    local android_output_dir="$DIST_DIR/android"
    mkdir -p "$android_output_dir"
    
    # Check for NDK
    if [ -z "$ANDROID_NDK_HOME" ]; then
        print_warning "ANDROID_NDK_HOME not set - attempting to use default locations"
        
        # Try ANDROID_SDK_ROOT first (set by setup-ndk action)
        if [ ! -z "$ANDROID_SDK_ROOT" ] && [ -d "$ANDROID_SDK_ROOT/ndk" ]; then
            export ANDROID_NDK_HOME="$ANDROID_SDK_ROOT/ndk/$(ls -1 $ANDROID_SDK_ROOT/ndk | tail -1)"
            print_info "Found NDK via ANDROID_SDK_ROOT: $ANDROID_NDK_HOME"
        # Try GitHub Actions location
        elif [ -d "/opt/hostedtoolcache/ndk" ]; then
            export ANDROID_NDK_HOME="/opt/hostedtoolcache/ndk/$(ls -1 /opt/hostedtoolcache/ndk | tail -1)"
            print_info "Found NDK at GitHub Actions location: $ANDROID_NDK_HOME"
        # Try standard Android SDK location
        elif [ -d "$HOME/Android/Sdk/ndk" ]; then
            export ANDROID_NDK_HOME="$HOME/Android/Sdk/ndk/$(ls -1 $HOME/Android/Sdk/ndk | tail -1)"
            print_info "Found NDK at standard location: $ANDROID_NDK_HOME"
        else
            print_error "ANDROID_NDK_HOME not set and NDK not found in standard locations"
            print_info "Checked locations:"
            print_info "  - ANDROID_SDK_ROOT/ndk (setup-ndk action)"
            print_info "  - /opt/hostedtoolcache/ndk (GitHub Actions)"
            print_info "  - $HOME/Android/Sdk/ndk (Standard Android SDK)"
            print_info "Please set ANDROID_NDK_HOME environment variable"
            return 1
        fi
    fi
    
    # Verify NDK installation
    if [ ! -d "$ANDROID_NDK_HOME" ]; then
        print_error "ANDROID_NDK_HOME points to non-existent directory: $ANDROID_NDK_HOME"
        return 1
    fi
    
    print_info "Using NDK: $ANDROID_NDK_HOME"
    if [ -f "$ANDROID_NDK_HOME/source.properties" ]; then
        print_info "NDK version: $(grep 'Pkg.Revision' $ANDROID_NDK_HOME/source.properties)"
    fi
    
    # Verify and install Rust targets
    print_subsection "Verifying Rust targets..."
    for target in "${android_targets[@]}"; do
        if ! rustup target list | grep -q "^$target (installed)"; then
            print_warning "Target $target not installed, installing..."
            rustup target install "$target"
        else
            print_success "Target $target is installed"
        fi
    done
    
    # Verify cargo-ndk is installed
    if ! command_exists cargo-ndk; then
        print_warning "cargo-ndk not found in PATH, installing..."
        cargo install cargo-ndk
    fi
    
    for target in "${android_targets[@]}"; do
        print_subsection "Building for $target..."
        
        cd "$PROJECT_ROOT"
        # Use cargo-ndk for proper Android NDK integration
        print_info "Invoking: cargo-ndk -t $target -o $WORKSPACE_TARGET/$target/release build -p matrix-crypto-android --release"
        if cargo-ndk -t "$target" -o "$WORKSPACE_TARGET/$target/release" build -p matrix-crypto-android --release; then
            print_success "Build succeeded for $target"
            
            # Copy the shared library
            local lib_file="$WORKSPACE_TARGET/$target/release/libmatrix_crypto_android.so"
            if verify_artifact "$lib_file" "Android shared library ($target)"; then
                # Create ABI-specific directory
                local abi_dir="$android_output_dir/lib/$target"
                mkdir -p "$abi_dir"
                cp "$lib_file" "$abi_dir/libmatrix_crypto_android.so"
                print_success "Copied to $abi_dir/libmatrix_crypto_android.so"
            else
                print_error "Failed to find library for $target"
                return 1
            fi
        else
            print_error "Build failed for $target"
            print_warning "Make sure ANDROID_NDK_HOME is set correctly"
            return 1
        fi
    done
    
    # Also copy to react-native package for convenience
    print_subsection "Copying to react-native-matrix-crypto package..."
    mkdir -p "$PACKAGE_DIR/android/src/main/jniLibs/arm64-v8a"
    mkdir -p "$PACKAGE_DIR/android/src/main/jniLibs/armeabi-v7a"
    mkdir -p "$PACKAGE_DIR/android/src/main/jniLibs/x86_64"
    
    cp "$android_output_dir/lib/aarch64-linux-android/libmatrix_crypto_android.so" \
       "$PACKAGE_DIR/android/src/main/jniLibs/arm64-v8a/"
    cp "$android_output_dir/lib/armv7-linux-androideabi/libmatrix_crypto_android.so" \
       "$PACKAGE_DIR/android/src/main/jniLibs/armeabi-v7a/"
    cp "$android_output_dir/lib/x86_64-linux-android/libmatrix_crypto_android.so" \
       "$PACKAGE_DIR/android/src/main/jniLibs/x86_64/"
    
    print_success "Copied to react-native package"
    
    return 0
}

# Function to generate Swift bindings (iOS)
generate_swift_bindings() {
    print_section "Generating Swift Bindings"
    
    local swift_output_dir="$DIST_DIR/swift"
    mkdir -p "$swift_output_dir"
    
    print_subsection "Generating Swift bindings..."
    
    # Use uniffi-bindgen to generate Swift code
    if command_exists uniffi-bindgen; then
        cd "$PROJECT_ROOT"
        uniffi-bindgen generate \
            --language swift \
            matrix-crypto-core/src/matrix_crypto.udl \
            --out-dir "$swift_output_dir"
        
        if [ -f "$swift_output_dir/matrix_crypto.swift" ]; then
            print_success "Generated Swift bindings"
            
            # Copy to package
            mkdir -p "$PACKAGE_DIR/ios/bindings"
            cp "$swift_output_dir/matrix_crypto.swift" "$PACKAGE_DIR/ios/bindings/"
            print_success "Copied Swift bindings to package"
        else
            print_warning "Swift bindings may not have been generated correctly"
        fi
    else
        print_warning "uniffi-bindgen not found - skipping Swift bindings generation"
        print_info "Install with: cargo install uniffi_bindgen"
    fi
    
    return 0
}

# Function to generate Kotlin bindings (Android)
generate_kotlin_bindings() {
    print_section "Generating Kotlin Bindings"
    
    local kotlin_output_dir="$DIST_DIR/kotlin"
    mkdir -p "$kotlin_output_dir"
    
    print_subsection "Generating Kotlin bindings..."
    
    # Use uniffi-bindgen to generate Kotlin code
    if command_exists uniffi-bindgen; then
        cd "$PROJECT_ROOT"
        uniffi-bindgen generate \
            --language kotlin \
            matrix-crypto-core/src/matrix_crypto.udl \
            --out-dir "$kotlin_output_dir"
        
        if [ -f "$kotlin_output_dir/matrix_crypto.kt" ]; then
            print_success "Generated Kotlin bindings"
            
            # Copy to package
            mkdir -p "$PACKAGE_DIR/android/bindings"
            cp "$kotlin_output_dir/matrix_crypto.kt" "$PACKAGE_DIR/android/bindings/"
            print_success "Copied Kotlin bindings to package"
        else
            print_warning "Kotlin bindings may not have been generated correctly"
        fi
    else
        print_warning "uniffi-bindgen not found - skipping Kotlin bindings generation"
    fi
    
    return 0
}

# Function to create distribution archive
create_distribution() {
    print_section "Creating Distribution Archive"
    
    local archive_name="matrix-crypto-bridge_${BUILD_TIMESTAMP}.tar.gz"
    local archive_path="$PROJECT_ROOT/$archive_name"
    
    print_subsection "Creating archive: $archive_name"
    
    cd "$DIST_DIR"
    tar -czf "$archive_path" .
    
    if [ -f "$archive_path" ]; then
        local size=$(du -h "$archive_path" | cut -f1)
        print_success "Distribution archive created: $archive_path ($size)"
        
        # Create checksum
        local checksum_file="$archive_path.sha256"
        sha256sum "$archive_path" > "$checksum_file"
        print_success "Checksum created: $checksum_file"
        
        return 0
    else
        print_error "Failed to create distribution archive"
        return 1
    fi
}

# Function to create build report
create_build_report() {
    print_section "Build Report"
    
    local report_file="$DIST_DIR/BUILD_REPORT.md"
    
    cat > "$report_file" << EOF
# Matrix Crypto Bridge - Build Report

## Build Information
- **Build Date**: $(date)
- **Build Timestamp**: $BUILD_TIMESTAMP
- **Project Root**: $PROJECT_ROOT

## iOS Libraries

### Device (aarch64-apple-ios)
EOF
    
    if [ -f "$DIST_DIR/ios/libmatrix_crypto_ios_aarch64-apple-ios.a" ]; then
        local size=$(du -h "$DIST_DIR/ios/libmatrix_crypto_ios_aarch64-apple-ios.a" | cut -f1)
        echo "- **File**: libmatrix_crypto_ios_aarch64-apple-ios.a" >> "$report_file"
        echo "- **Size**: $size" >> "$report_file"
    fi
    echo "" >> "$report_file"
    
    echo "### Simulator (x86_64-apple-ios)" >> "$report_file"
    if [ -f "$DIST_DIR/ios/libmatrix_crypto_ios_x86_64-apple-ios.a" ]; then
        local size=$(du -h "$DIST_DIR/ios/libmatrix_crypto_ios_x86_64-apple-ios.a" | cut -f1)
        echo "- **File**: libmatrix_crypto_ios_x86_64-apple-ios.a" >> "$report_file"
        echo "- **Size**: $size" >> "$report_file"
    fi
    echo "" >> "$report_file"
    
    echo "### Universal Binary" >> "$report_file"
    if [ -f "$DIST_DIR/ios/libmatrix_crypto_ios.a" ]; then
        local size=$(du -h "$DIST_DIR/ios/libmatrix_crypto_ios.a" | cut -f1)
        echo "- **File**: libmatrix_crypto_ios.a" >> "$report_file"
        echo "- **Size**: $size" >> "$report_file"
    fi
    echo "" >> "$report_file"
    
    echo "## Android Libraries" >> "$report_file"
    echo "" >> "$report_file"
    
    if [ -d "$DIST_DIR/android/lib" ]; then
        for abi in aarch64-linux-android armv7-linux-androideabi x86_64-linux-android; do
            if [ -f "$DIST_DIR/android/lib/$abi/libmatrix_crypto_android.so" ]; then
                local size=$(du -h "$DIST_DIR/android/lib/$abi/libmatrix_crypto_android.so" | cut -f1)
                echo "### $abi" >> "$report_file"
                echo "- **File**: libmatrix_crypto_android.so" >> "$report_file"
                echo "- **Size**: $size" >> "$report_file"
                echo "" >> "$report_file"
            fi
        done
    fi
    
    echo "## Language Bindings" >> "$report_file"
    echo "" >> "$report_file"
    
    if [ -f "$DIST_DIR/swift/matrix_crypto.swift" ]; then
        echo "- **Swift**: Generated" >> "$report_file"
    fi
    
    if [ -f "$DIST_DIR/kotlin/matrix_crypto.kt" ]; then
        echo "- **Kotlin**: Generated" >> "$report_file"
    fi
    echo "" >> "$report_file"
    
    echo "## Integration Instructions" >> "$report_file"
    echo "" >> "$report_file"
    echo "### iOS" >> "$report_file"
    echo "\`\`\`" >> "$report_file"
    echo "1. Copy libmatrix_crypto_ios.a to your Xcode project" >> "$report_file"
    echo "2. Add Swift bindings (matrix_crypto.swift) to your project" >> "$report_file"
    echo "3. Link the static library in Build Phases" >> "$report_file"
    echo "4. Import and use: import matrix_crypto" >> "$report_file"
    echo "\`\`\`" >> "$report_file"
    echo "" >> "$report_file"
    
    echo "### Android" >> "$report_file"
    echo "\`\`\`" >> "$report_file"
    echo "1. Copy .so files to jniLibs directory:" >> "$report_file"
    echo "   app/src/main/jniLibs/arm64-v8a/" >> "$report_file"
    echo "   app/src/main/jniLibs/armeabi-v7a/" >> "$report_file"
    echo "   app/src/main/jniLibs/x86_64/" >> "$report_file"
    echo "2. Add Kotlin bindings to your project" >> "$report_file"
    echo "3. Load library: System.loadLibrary(\"matrix_crypto_android\")" >> "$report_file"
    echo "\`\`\`" >> "$report_file"
    echo "" >> "$report_file"
    
    print_success "Build report created: $report_file"
}

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
    ios              Build iOS libraries only
    android          Build Android libraries only
    swift            Generate Swift bindings only
    kotlin           Generate Kotlin bindings only
    all              Build everything (iOS, Android, bindings, archive)
    clean            Clean build artifacts
    help             Show this help message

Environment Variables:
    ANDROID_NDK_HOME    Path to Android NDK (required for Android builds)

Examples:
    $0 all                    # Build everything
    $0 ios                    # Build iOS only
    $0 android                # Build Android only
    ANDROID_NDK_HOME=/path/to/ndk $0 android

EOF
}

# Parse arguments
COMMAND="${1:-all}"

case $COMMAND in
    ios)
        build_ios
        ;;
    android)
        build_android
        ;;
    swift)
        generate_swift_bindings
        ;;
    kotlin)
        generate_kotlin_bindings
        ;;
    all)
        print_section "Matrix Crypto Bridge - Full Build"
        
        # Clean dist directory
        rm -rf "$DIST_DIR"
        mkdir -p "$DIST_DIR"
        
        # Build all components
        build_ios || exit 1
        build_android || exit 1
        generate_swift_bindings || true
        generate_kotlin_bindings || true
        
        # Create distribution
        create_build_report
        create_distribution
        
        print_section "Build Complete!"
        print_success "All artifacts available in: $DIST_DIR"
        print_success "Distribution archive: $PROJECT_ROOT/matrix-crypto-bridge_${BUILD_TIMESTAMP}.tar.gz"
        ;;
    clean)
        print_section "Cleaning Build Artifacts"
        rm -rf "$DIST_DIR"
        rm -f "$PROJECT_ROOT"/matrix-crypto-bridge_*.tar.gz
        rm -f "$PROJECT_ROOT"/matrix-crypto-bridge_*.tar.gz.sha256
        print_success "Cleaned"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
