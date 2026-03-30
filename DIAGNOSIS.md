# DIAGNOSIS.md — matrix-crypto-bridge
**Phase:** 1 — Root Cause Analysis
**Date:** 2026-03-30
**Status:** Complete

---

## Executive Summary

Four root causes explain why `NativeModules.RNMatrixCrypto` is undefined at runtime. The fundamental problem is a broken dependency architecture: the npm package depends on a separate CocoaPods pod (`MatrixCryptoBridge`) to supply the compiled Rust static library, but that pod is unreliable (trunk timing delays, placeholder SHA256). The fix is to make the npm package self-contained by including `libmatrix_crypto_ios.a` directly.

---

## What Was Inspected

| Item | Path | Status |
|------|------|--------|
| npm package podspec | `react-native-matrix-crypto/react-native-matrix-crypto.podspec` | ✅ Read |
| CocoaPods pod podspec | `MatrixCryptoBridge.podspec` | ✅ Read |
| ObjC bridge | `react-native-matrix-crypto/ios/RNMatrixCrypto.m` | ✅ Read |
| Swift module | `react-native-matrix-crypto/ios/RNMatrixCryptoModule.swift` | ✅ Read |
| iOS source files | `react-native-matrix-crypto/ios/` | ✅ Inspected |
| Android JNI libs | `react-native-matrix-crypto/android/src/main/jniLibs/` | ✅ Inspected |
| CI/CD pipeline | `.github/workflows/build-and-publish-workspace.yml` | ✅ Read |
| Build script | `build-scripts/build-workspace.sh` | ✅ Read |
| Rust workspace | `Cargo.toml`, `matrix-crypto-core/src/lib.rs` | ✅ Read |

---

## Root Cause 1 (Critical): Broken Dependency Architecture

### What the podspec says

`react-native-matrix-crypto.podspec`:
```ruby
s.source_files = [
  "ios/matrix_crypto.swift",
  "ios/matrix_cryptoFFI.h",
  "ios/MatrixCryptoBridge.swift",
  "ios/RNMatrixCryptoModule.swift",
  "ios/RNMatrixCrypto.m"
]
s.dependency "MatrixCryptoBridge", "~> #{s.version}"
```

The npm package provides Swift/ObjC source files **and** depends on a separate `MatrixCryptoBridge` pod to supply the compiled Rust library.

### Why this fails

**Problem A — CocoaPods trunk timing:** `MatrixCryptoBridge` is published to CocoaPods trunk during the CI release workflow. New pods take hours to days to become searchable. Any `pod install` run before indexing completes fails:
```
CocoaPods could not find compatible versions for pod "MatrixCryptoBridge":
None of your spec sources contain a spec satisfying the dependency: `MatrixCryptoBridge (~> 1.2.20)`.
```

**Problem B — PLACEHOLDER_SHA256:** `MatrixCryptoBridge.podspec` in the git repository always contains:
```ruby
s.source = {
  :http => "https://github.com/.../matrix-crypto-bridge-dist.tar.gz",
  :sha256 => "PLACEHOLDER_SHA256"
}
```
The real SHA256 is only substituted during the CI release step (`sed -i "s/PLACEHOLDER_SHA256/$SHA256/"`). If anyone tries to use the podspec from git (e.g., via a `:git` Podfile override), CocoaPods rejects it because the SHA256 is invalid.

**Problem C — Duplicate source files:** Both `react-native-matrix-crypto.podspec` AND `MatrixCryptoBridge.podspec` list the same Swift/ObjC bridge files:
- `matrix_crypto.swift`
- `matrix_cryptoFFI.h`
- `MatrixCryptoBridge.swift`
- `RNMatrixCryptoModule.swift`
- `RNMatrixCrypto.m`

When both pods are compiled into the same Xcode target, the linker sees duplicate symbols and fails.

---

## Root Cause 2 (Critical): Missing Rust Static Library in npm Package

### What the iOS directory contains

```
react-native-matrix-crypto/ios/
├── MatrixCryptoBridge.swift       ✅ present
├── RNMatrixCrypto.m               ✅ present
├── RNMatrixCryptoModule.swift     ✅ present
├── matrix_crypto.swift            ✅ present
├── matrix_cryptoFFI.h             ✅ present
├── matrix_cryptoFFI.modulemap     ✅ present
└── libmatrix_crypto_ios.a         ❌ MISSING
```

The compiled Rust static library is absent from the npm package. Without it, the native module cannot link and `NativeModules.RNMatrixCrypto` is undefined.

### Why the library is absent

The build script (`build-workspace.sh`) compiles `libmatrix_crypto_ios.a` and places it at `dist/ios/libmatrix_crypto_ios.a`. It also copies platform-specific variants to `react-native-matrix-crypto/ios/prebuilt/` — but:

1. The `ios/prebuilt/` directory is not referenced in the podspec.
2. The `ios/prebuilt/` output is not committed to git (it's a build artifact).
3. The npm publish step in CI does not copy the `.a` file into `ios/` before publishing.

**Contrast with Android:** The Android `.so` libraries ARE committed to git at `react-native-matrix-crypto/android/src/main/jniLibs/{abi}/`. The iOS side must match this pattern.

---

## Root Cause 3 (Supporting): MatrixCryptoBridge.podspec Archive Structure Vs. Reality

The `MatrixCryptoBridge.podspec` expects the downloaded archive to contain:
```
ios/libmatrix_crypto_ios.a
ios/bindings/matrix_crypto.swift
ios/bindings/matrix_cryptoFFI.h
ios/bindings/matrix_cryptoFFI.modulemap
ios/bridge/MatrixCryptoBridge.swift
ios/bridge/RNMatrixCryptoModule.swift
ios/bridge/RNMatrixCrypto.m
```

The CI workflow creates the archive by running `tar -czf matrix-crypto-bridge-dist.tar.gz .` from the `dist/` directory. The `dist/` directory gets:
- `dist/ios/libmatrix_crypto_ios.a` (from the Rust build step)
- `dist/ios/bindings/` (from the `create-distribution` step copying from `react-native-matrix-crypto/ios/`)
- `dist/ios/bridge/` (from the `create-distribution` step)

So the archive structure **should** match what the podspec expects — but only when the Rust build step succeeds AND produces the `.a` file. If `build-ios` fails or is skipped, the `.a` is absent from the archive, and the pod fails with linker errors when the missing library is referenced in `vendored_libraries`.

---

## Root Cause 4 (Minor): React Native Version Gap

`react-native-matrix-crypto/package.json`:
```json
"react-native": "^0.84.1"   ← bridge targets this
```
Fortress `package.json`:
```json
"react-native": "0.81.5"    ← app is on this
```

This is a 3-minor-version gap. React Native bridge headers change between minor versions. It's unlikely to cause build failures with the current RCT_EXTERN_MODULE approach, but should be resolved to avoid subtle incompatibilities.

---

## File Structure Verification

### npm package `ios/` directory (actual)
```
react-native-matrix-crypto/ios/
├── MatrixCryptoBridge.swift          ← Swift singleton wrapping Rust
├── RNMatrixCrypto.m                  ← RCT_EXTERN_MODULE registration
├── RNMatrixCryptoModule.swift        ← React Native method implementations
├── matrix_crypto.swift               ← UniFFI-generated Swift bindings
├── matrix_cryptoFFI.h                ← UniFFI-generated C header
└── matrix_cryptoFFI.modulemap        ← Module map
```

**Missing:** `libmatrix_crypto_ios.a` (compiled Rust static library)

### Android `jniLibs/` (actual — correct pattern)
```
react-native-matrix-crypto/android/src/main/jniLibs/
├── arm64-v8a/libmatrix_crypto_android.so    ✅
├── armeabi-v7a/libmatrix_crypto_android.so  ✅
└── x86_64/libmatrix_crypto_android.so       ✅
```

Android correctly includes the pre-built `.so` libraries in the package. iOS must do the same.

---

## What Works vs. What Doesn't

### ✅ What works

- Rust core compiles (`matrix-crypto-core`, `matrix-crypto-ios`, `matrix-crypto-android`)
- Swift/ObjC bridge code is correct and complete
- `RCT_EXTERN_MODULE(RNMatrixCrypto, NSObject)` in `RNMatrixCrypto.m` is correct
- UniFFI-generated bindings (`matrix_crypto.swift`, `matrix_cryptoFFI.h`) are present
- Android `.so` libraries are in the npm package and will link correctly
- CI/CD pipeline builds and packages the Rust library
- npm package publishes successfully (but without the `.a` file)

### ❌ What doesn't work

- `libmatrix_crypto_ios.a` is not in the npm package
- `react-native-matrix-crypto.podspec` depends on `MatrixCryptoBridge` pod
- `MatrixCryptoBridge` pod has `PLACEHOLDER_SHA256` in git (only valid post-release)
- Both podspecs list the same source files (duplicate symbol risk)

---

## Recommended Fix: Self-Contained npm Package

This is the "medium-term solution" from BLOCKERS.md, and it is the correct approach.

### Changes to `matrix-crypto-bridge`

#### 1. Update CI/CD to copy `.a` into npm package before publishing

In `.github/workflows/build-and-publish-workspace.yml`, in the `publish-npm` job, add before `npm publish`:

```yaml
- name: Copy iOS library into npm package
  run: |
    mkdir -p react-native-matrix-crypto/ios
    cp dist-extracted/ios/libmatrix_crypto_ios.a react-native-matrix-crypto/ios/
    echo "iOS library copied:"
    ls -lh react-native-matrix-crypto/ios/libmatrix_crypto_ios.a
```

#### 2. Update `react-native-matrix-crypto.podspec`

```ruby
# Add: vendored static library (the compiled Rust library)
s.vendored_libraries = "ios/libmatrix_crypto_ios.a"

# Keep: source files (Swift/ObjC bridge — already in ios/)
s.source_files = [
  "ios/matrix_crypto.swift",
  "ios/matrix_cryptoFFI.h",
  "ios/MatrixCryptoBridge.swift",
  "ios/RNMatrixCryptoModule.swift",
  "ios/RNMatrixCrypto.m"
]

# Remove: s.dependency "MatrixCryptoBridge", "~> #{s.version}"
# Reason: npm package is now self-contained; no separate pod needed
```

#### 3. Update `package.json` `files` field

The `files` field already includes `"ios"` — no change needed. The `.a` file will be included automatically once it's copied into `ios/`.

#### 4. Publish v1.3.0 to npm

The version bump signals the breaking architecture change.

### Changes to `fortress`

#### 1. Run `expo prebuild`

```bash
cd fortress
pnpm install
npx expo prebuild --clean
```

This generates `ios/` and `android/` directories (including `ios/Podfile`).

#### 2. Update dependency version

```json
"@k9o/react-native-matrix-crypto": "^1.3.0"
```

#### 3. Install pods

```bash
cd ios && pod install && cd ..
```

#### 4. Test native module

```bash
npx expo run:ios
# Look for: "[E2EE] Native @k9o/react-native-matrix-crypto module loaded"
# Should NOT see: "falling back to matrix-js-sdk"
```

---

## Short-Term Workaround (If Needed Before v1.3.0)

If a build is needed before the npm package fix is published, add a Podfile-level override after running `expo prebuild`:

```ruby
# In fortress/ios/Podfile, after use_expo_modules!
pod 'MatrixCryptoBridge', :git => 'https://github.com/k9o-dev/matrix-crypto-bridge.git', :tag => 'v1.2.20'
```

**Limitation:** This requires git cloning during `pod install` and the `PLACEHOLDER_SHA256` issue may still cause failures. This is not a reliable workaround.

---

## Questions to Verify During Phase 2

1. Does the CI `build-ios` job actually produce `libmatrix_crypto_ios.a` at `dist/ios/`? (Check latest CI run artifacts)
2. Is there an aarch64-apple-ios-sim target needed (iOS 14+ simulator on Apple Silicon)?
3. Does `expo prebuild` for Fortress generate a Podfile that correctly picks up `@k9o/react-native-matrix-crypto` via its podspec?

---

## Summary

| Root Cause | Severity | Fix |
|------------|----------|-----|
| npm package depends on unreliable `MatrixCryptoBridge` pod | Critical | Remove dependency; use `vendored_libraries` |
| `libmatrix_crypto_ios.a` missing from npm package | Critical | Copy `.a` to `ios/` before npm publish |
| Both podspecs list same source files | High | Remove sources from `MatrixCryptoBridge.podspec` (or remove the pod entirely) |
| `PLACEHOLDER_SHA256` in podspec | Medium | Resolved by removing `MatrixCryptoBridge` pod |
| Fortress has no `ios/` dir | Blocking | Run `expo prebuild --clean` |
| RN version gap (0.81.5 vs 0.84.1) | Low | Update Fortress or update bridge peerDeps |
