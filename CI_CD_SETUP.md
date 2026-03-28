# CI/CD Pipeline Setup for NPM Publishing

This guide provides step-by-step instructions for setting up automated CI/CD pipelines to build native libraries and publish the `@k9o/react-native-matrix-crypto` package to NPM using GitHub Actions.

## Table of Contents

1. [Overview](#overview)
2. [GitHub Actions Workflow](#github-actions-workflow)
3. [Setup Instructions](#setup-instructions)
4. [Build Process](#build-process)
5. [Publishing to NPM](#publishing-to-npm)
6. [Troubleshooting](#troubleshooting)

---

## Overview

The CI/CD pipeline automates the complete build and publish process:

1. **Build iOS Libraries** (macOS runner)
   - Compile for aarch64-apple-ios (device)
   - Compile for x86_64-apple-ios (simulator)
   - Upload artifacts

2. **Build Android Libraries** (Ubuntu runner)
   - Compile for aarch64-linux-android (ARM64)
   - Compile for armv7-linux-androideabi (ARMv7)
   - Compile for x86_64-linux-android (x86_64)
   - Upload artifacts

3. **Package for NPM** (Ubuntu runner)
   - Download all build artifacts
   - Organize iOS libraries in `ios/prebuilt/`
   - Organize Android libraries in `android/src/main/jniLibs/`
   - Build TypeScript
   - Verify package contents

4. **Publish to NPM** (Ubuntu runner)
   - Publish to NPM registry
   - Create GitHub Release with build information

### Benefits

- ✅ Fully automated builds on version tags
- ✅ Pre-built native libraries included in NPM package
- ✅ Auto-linking via CocoaPods (iOS) and Gradle (Android)
- ✅ No manual build steps required for users
- ✅ Consistent build environment across platforms
- ✅ Multi-platform support (iOS device, iOS simulator, Android ARM64/ARMv7/x86_64)
- ✅ Artifact storage and GitHub Releases

---

## GitHub Actions Workflow

### File: `.github/workflows/build-and-publish.yml`

The workflow is triggered by:

1. **Git Tags** matching `v*` (e.g., `v1.0.0`, `v1.1.0`)
2. **Manual Trigger** via GitHub UI with `publish: true`
3. **Pushes to main/develop** (builds only, no publish)

### Workflow Structure

```
┌─────────────────────────────────────────────────────────────┐
│ Trigger: Push tag (v*) or manual workflow_dispatch         │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
    ┌────▼─────┐                    ┌────▼──────────┐
    │ build-ios │                    │ build-android │
    │ (macOS)   │                    │ (Ubuntu)      │
    └────┬─────┘                    └────┬──────────┘
         │                               │
         │  aarch64-apple-ios            │  aarch64-linux-android
         │  x86_64-apple-ios             │  armv7-linux-androideabi
         │                               │  x86_64-linux-android
         │                               │
         └───────────────┬───────────────┘
                         │
                    ┌────▼────────┐
                    │   package   │
                    │ (Ubuntu)    │
                    └────┬────────┘
                         │
                    ┌────▼────────┐
                    │  publish    │
                    │ (if tagged) │
                    └────┬────────┘
                         │
                    ┌────▼────────┐
                    │   notify    │
                    │ (always)    │
                    └─────────────┘
```

### Job Details

#### Job 1: build-ios

**Runs on:** `macos-latest`

**Strategy:** Matrix build for two targets
- `aarch64-apple-ios` (device)
- `x86_64-apple-ios` (simulator)

**Steps:**
1. Checkout code
2. Setup Rust with iOS targets
3. Cache Rust build
4. Build iOS library
5. Upload artifact (1-day retention)

**Output:** `libmatrix_crypto_core.a` files

#### Job 2: build-android

**Runs on:** `ubuntu-latest`

**Targets:**
- `aarch64-linux-android` (ARM64)
- `armv7-linux-androideabi` (ARMv7)
- `x86_64-linux-android` (x86_64)

**Steps:**
1. Checkout code
2. Setup Rust with Android targets
3. Setup Android NDK r25c
4. Cache Rust build
5. Build for all Android architectures
6. Upload artifact (1-day retention)

**Output:** `libmatrix_crypto_core.so` files

#### Job 3: package

**Runs on:** `ubuntu-latest`

**Dependencies:** Requires build-ios and build-android to complete

**Steps:**
1. Download iOS artifacts
2. Download Android artifacts
3. Organize iOS libraries
4. Organize Android libraries
5. Setup Node.js 18
6. Install dependencies
7. Build TypeScript
8. Verify package contents
9. Upload packaged artifact (7-day retention)

**Output:** Complete NPM package with native libraries

#### Job 4: publish

**Runs on:** `ubuntu-latest`

**Condition:** Only runs if git tag matches `v*` OR manual trigger with `publish: true`

**Steps:**
1. Download packaged artifact
2. Setup Node.js with NPM registry
3. Publish to NPM with `--access public`
4. Create GitHub Release with build information

**Requires:** `NPM_TOKEN` secret

#### Job 5: notify

**Runs on:** `ubuntu-latest`

**Condition:** Always runs

**Steps:**
1. Check build status
2. Comment on PR if applicable

---

## Setup Instructions

### Step 1: Create GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings → Secrets and variables → Actions**
3. Click **New repository secret**
4. Add the following secret:

| Secret Name | Value |
|-------------|-------|
| `NPM_TOKEN` | Your NPM authentication token |

**To create NPM token:**
```bash
npm login
npm token create --read-only
```

### Step 2: Add GitHub Actions Workflow

The workflow file should be at `.github/workflows/build-and-publish.yml`

If not already present:

```bash
mkdir -p .github/workflows
touch .github/workflows/build-and-publish.yml
```

Copy the workflow YAML content into the file.

### Step 3: Verify Workflow Setup

1. Go to your GitHub repository
2. Click the **Actions** tab
3. You should see "Build and Publish to NPM" workflow listed
4. Click on it to view workflow details

### Step 4: Test Local Build

Before publishing, test the build scripts locally:

```bash
# Build all platforms
bash build-scripts/build-and-package.sh all

# Verify package contents
ls -la react-native-matrix-crypto/ios/prebuilt/
ls -la react-native-matrix-crypto/android/src/main/jniLibs/

# Build TypeScript
cd react-native-matrix-crypto
npm run build
```

### Step 5: Create Release

To trigger the automated build and publish:

```bash
# Update version
npm version patch    # or minor/major

# Create git tag
git tag -a v1.1.0 -m "Release v1.1.0"

# Push to GitHub
git push origin main
git push origin v1.1.0
```

The GitHub Actions workflow will automatically:
1. Build iOS and Android libraries
2. Package for NPM
3. Publish to NPM
4. Create GitHub Release

---

## Build Process

### Local Development

For local testing before publishing:

```bash
# Build and package all platforms
bash build-scripts/build-and-package.sh all

# Create npm link for testing
bash build-scripts/build-local.sh

# Test in Fortress app
cd /path/to/fortress
npm link @k9o/react-native-matrix-crypto
cd ios && pod install && cd ..
npm run dev:ios

# Unlink when done
npm unlink @k9o/react-native-matrix-crypto
```

### Automated Build (GitHub Actions)

The CI/CD pipeline automatically builds when:

1. **Git tag is pushed** (e.g., `v1.0.0`)
   - Builds iOS and Android
   - Packages for NPM
   - Publishes to NPM
   - Creates GitHub Release

2. **Manual trigger**
   - Go to Actions tab
   - Select "Build and Publish to NPM"
   - Click "Run workflow"
   - Set "Publish to NPM" to true
   - Click "Run workflow"

3. **Push to main/develop** (no tag)
   - Builds iOS and Android
   - Packages for NPM
   - Does NOT publish

---

## Publishing to NPM

### Automatic Publishing (Recommended)

```bash
# 1. Update version
npm version patch

# 2. Create git tag
git tag -a v1.1.0 -m "Release v1.1.0"

# 3. Push to GitHub
git push origin main
git push origin v1.1.0

# GitHub Actions automatically publishes
```

### Manual Publishing

If you need to publish manually:

```bash
cd react-native-matrix-crypto

# Ensure everything is built
npm run build

# Verify package contents
npm pack --dry-run

# Publish to NPM
npm publish --access public

# Or with specific tag
npm publish --tag beta --access public
```

### Verify Publication

```bash
# Check NPM registry
npm view @k9o/react-native-matrix-crypto

# View specific version
npm view @k9o/react-native-matrix-crypto@1.1.0

# List all versions
npm view @k9o/react-native-matrix-crypto versions
```

---

## Build Artifacts

### Package Structure

```
@k9o/react-native-matrix-crypto@1.1.0
├── lib/                          # Compiled TypeScript
│   ├── index.js
│   ├── CryptoAPI.js
│   ├── NativeMatrixCrypto.js
│   └── index.d.ts
├── src/                          # TypeScript source
├── ios/
│   ├── react-native-matrix-crypto.podspec
│   ├── prebuilt/
│   │   ├── libmatrix_crypto_core_arm64.a
│   │   └── libmatrix_crypto_core_sim.a
│   └── RNMatrixCryptoModule.swift
├── android/
│   ├── build.gradle
│   ├── src/main/jniLibs/
│   │   ├── arm64-v8a/libmatrix_crypto_core.so
│   │   ├── armeabi-v7a/libmatrix_crypto_core.so
│   │   └── x86_64/libmatrix_crypto_core.so
│   └── RNMatrixCryptoModule.kt
├── package.json
└── README.md
```

### Artifact Retention

| Artifact | Retention | Purpose |
|----------|-----------|---------|
| iOS libraries | 1 day | Build cache |
| Android libraries | 1 day | Build cache |
| NPM package | 7 days | Backup |
| GitHub Release | Permanent | Public distribution |

---

## Troubleshooting

### Issue: "Workflow not triggering"

**Solution:**
1. Verify the workflow file is in `.github/workflows/build-and-publish.yml`
2. Check branch name matches trigger conditions
3. Ensure git tag matches `v*` pattern
4. Manually trigger via Actions tab

### Issue: "Build failed: NDK not found"

**Solution:**
- The workflow uses NDK r25c
- Ensure `ANDROID_NDK_HOME` is set correctly
- Check NDK version compatibility

### Issue: "NPM publish failed"

**Solution:**
1. Verify `NPM_TOKEN` secret is set
2. Check token has `write:packages` permission
3. Verify package name is correct
4. Check version number is unique

### Issue: "Artifacts not uploading"

**Solution:**
1. Verify artifact paths are correct
2. Check that build completed successfully
3. Ensure retention days are set

### Issue: "GitHub Release not created"

**Solution:**
1. Verify git tag matches `v*` pattern
2. Check `GITHUB_TOKEN` has permissions
3. Ensure publish job completed successfully

---

## Best Practices

1. **Use semantic versioning:**
   ```bash
   npm version patch    # Bug fixes (1.0.0 → 1.0.1)
   npm version minor    # New features (1.0.0 → 1.1.0)
   npm version major    # Breaking changes (1.0.0 → 2.0.0)
   ```

2. **Test locally before publishing:**
   ```bash
   bash build-scripts/build-local.sh
   npm link
   # Test in app
   npm unlink
   ```

3. **Update changelog:**
   - Document all changes
   - Include breaking changes
   - Link to related issues

4. **Verify package contents:**
   ```bash
   npm pack --dry-run
   ```

5. **Monitor build status:**
   - Check Actions tab regularly
   - Set up email notifications
   - Review build logs for warnings

---

## Next Steps

1. Add `NPM_TOKEN` secret to GitHub
2. Verify workflow file is in place
3. Test local build with `build-scripts/build-and-package.sh all`
4. Create a test release with `npm version patch`
5. Push git tag to trigger automated build
6. Verify package on NPM registry
7. Test installation in new project

---

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [NPM Publishing Guide](https://docs.npmjs.com/packages-and-modules/contributing-packages-to-the-registry)
- [Semantic Versioning](https://semver.org/)
- [React Native Native Modules](https://reactnative.dev/docs/native-modules-intro)
- [CocoaPods Documentation](https://guides.cocoapods.org/)
- [Gradle Documentation](https://gradle.org/guides/)
