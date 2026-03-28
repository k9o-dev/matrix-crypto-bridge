# Matrix Crypto Bridge - Build Guide

This guide explains how to build the Matrix Crypto Bridge for iOS and Android platforms.

## Prerequisites

### macOS (for iOS builds)
- Xcode Command Line Tools: `xcode-select --install`
- Rust toolchain: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- iOS targets:
  ```bash
  rustup target add aarch64-apple-ios x86_64-apple-ios
  ```

### Linux (for Android builds)
- Rust toolchain: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- Android NDK (r26 or later)
- Android targets:
  ```bash
  rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
  ```

### All Platforms
- Cargo (included with Rust)
- Optional: `uniffi-bindgen` for generating language bindings
  ```bash
  cargo install uniffi_bindgen
  ```

## Building

### Quick Start

Build everything (iOS, Android, bindings, and distribution archive):

```bash
./build-scripts/build-workspace.sh all
```

### Platform-Specific Builds

**iOS only:**
```bash
./build-scripts/build-workspace.sh ios
```

**Android only:**
```bash
export ANDROID_NDK_HOME=/path/to/ndk
./build-scripts/build-workspace.sh android
```

**Generate Swift bindings:**
```bash
./build-scripts/build-workspace.sh swift
```

**Generate Kotlin bindings:**
```bash
./build-scripts/build-workspace.sh kotlin
```

### Clean Build Artifacts

```bash
./build-scripts/build-workspace.sh clean
```

## Build Output

After a successful build, artifacts are organized in the `dist/` directory:

```
dist/
├── ios/
│   ├── libmatrix_crypto_ios_aarch64-apple-ios.a    (device)
│   ├── libmatrix_crypto_ios_x86_64-apple-ios.a     (simulator)
│   └── libmatrix_crypto_ios.a                       (universal binary)
├── android/
│   └── lib/
│       ├── aarch64-linux-android/
│       │   └── libmatrix_crypto_android.so
│       ├── armv7-linux-androideabi/
│       │   └── libmatrix_crypto_android.so
│       └── x86_64-linux-android/
│           └── libmatrix_crypto_android.so
├── swift/
│   └── matrix_crypto.swift
├── kotlin/
│   └── matrix_crypto.kt
└── BUILD_REPORT.md
```

Libraries are also copied to the `react-native-matrix-crypto/` package for convenience:

```
react-native-matrix-crypto/
├── ios/
│   ├── prebuilt/                    (static libraries)
│   └── bindings/                    (Swift bindings)
└── android/
    ├── src/main/jniLibs/            (shared libraries)
    └── bindings/                    (Kotlin bindings)
```

## iOS Integration

### Using the Universal Binary

1. **Copy the library to your Xcode project:**
   ```bash
   cp dist/ios/libmatrix_crypto_ios.a /path/to/your/project/
   ```

2. **Add to Build Phases:**
   - In Xcode, select your target
   - Go to Build Phases → Link Binary With Libraries
   - Click the + button and add `libmatrix_crypto_ios.a`

3. **Add Swift bindings:**
   ```bash
   cp dist/swift/matrix_crypto.swift /path/to/your/project/
   ```

4. **Use in Swift:**
   ```swift
   import matrix_crypto
   
   let crypto = try createMatrixCrypto(
       userId: "@user:example.com",
       deviceId: "ABCDEFG",
       pickleKey: "your-pickle-key"
   )
   ```

### Using Separate Architectures

If you need to link against specific architectures:

- **Device (arm64)**: `dist/ios/libmatrix_crypto_ios_aarch64-apple-ios.a`
- **Simulator (x86_64)**: `dist/ios/libmatrix_crypto_ios_x86_64-apple-ios.a`

## Android Integration

### Gradle Setup

1. **Copy shared libraries to jniLibs:**
   ```bash
   mkdir -p app/src/main/jniLibs/{arm64-v8a,armeabi-v7a,x86_64}
   
   cp dist/android/lib/aarch64-linux-android/libmatrix_crypto_android.so \
      app/src/main/jniLibs/arm64-v8a/
   
   cp dist/android/lib/armv7-linux-androideabi/libmatrix_crypto_android.so \
      app/src/main/jniLibs/armeabi-v7a/
   
   cp dist/android/lib/x86_64-linux-android/libmatrix_crypto_android.so \
      app/src/main/jniLibs/x86_64/
   ```

2. **Add Kotlin bindings:**
   ```bash
   cp dist/kotlin/matrix_crypto.kt /path/to/your/project/src/main/kotlin/
   ```

3. **Load the library in Kotlin:**
   ```kotlin
   init {
       System.loadLibrary("matrix_crypto_android")
   }
   ```

4. **Use the crypto module:**
   ```kotlin
   val crypto = createMatrixCrypto(
       userId = "@user:example.com",
       deviceId = "ABCDEFG",
       pickleKey = "your-pickle-key"
   )
   ```

## Troubleshooting

### iOS Build Issues

**Error: "target `aarch64-apple-ios` not installed"**
```bash
rustup target add aarch64-apple-ios x86_64-apple-ios
```

**Error: "lipo not found"**
This is expected on non-macOS systems. The script will skip universal binary creation.

### Android Build Issues

**Error: "ANDROID_NDK_HOME not set"**
```bash
export ANDROID_NDK_HOME=/path/to/android-ndk-r26
./build-scripts/build-workspace.sh android
```

**Error: "cannot produce cdylib for target"**
Ensure you're on a Linux system with the Android NDK installed. The build script will attempt to auto-detect the NDK.

### Bindings Generation Issues

**Error: "uniffi-bindgen not found"**
```bash
cargo install uniffi_bindgen
```

## Distribution Archive

After a full build, a distribution archive is created:

```bash
matrix-crypto-bridge_20240328_041234.tar.gz
matrix-crypto-bridge_20240328_041234.tar.gz.sha256
```

To verify the archive:
```bash
sha256sum -c matrix-crypto-bridge_20240328_041234.tar.gz.sha256
```

## Continuous Integration

The build process is designed to work with CI/CD systems. Example GitHub Actions workflow:

```yaml
name: Build Matrix Crypto Bridge

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          targets: aarch64-apple-ios,x86_64-apple-ios
      - run: ./build-scripts/build-workspace.sh ios
      - uses: actions/upload-artifact@v3
        with:
          name: ios-libraries
          path: dist/ios/
```

## Performance Notes

- **First build**: 5-10 minutes (dependencies are compiled)
- **Incremental builds**: 1-2 minutes
- **Full build (iOS + Android + bindings)**: 15-20 minutes

Build times depend on your system specifications and network speed.

## Support

For issues or questions:
1. Check the build output for specific error messages
2. Verify all prerequisites are installed
3. Ensure environment variables are set correctly
4. Review the troubleshooting section above
5. Check the GitHub repository for known issues

## License

Matrix Crypto Bridge is licensed under the Apache License 2.0. See LICENSE file for details.
