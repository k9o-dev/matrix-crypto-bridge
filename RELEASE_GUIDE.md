# Matrix Crypto Bridge - Release & Publishing Guide

## Overview

This guide covers the complete process of building, testing, and publishing the `@k9o/react-native-matrix-crypto` package to NPM.

## Prerequisites

- Rust installed and configured
- Android NDK installed (for Android builds)
- Xcode installed (for iOS builds)
- Node.js 18+ installed
- NPM account with access to `@k9o` organization
- GitHub repository with write access

## Release Process

### Step 1: Prepare Release

#### 1.1 Update Version

```bash
cd react-native-matrix-crypto

# Update version in package.json
npm version patch    # for bug fixes (1.0.0 → 1.0.1)
npm version minor    # for new features (1.0.0 → 1.1.0)
npm version major    # for breaking changes (1.0.0 → 2.0.0)
```

#### 1.2 Update Changelog

Create or update `CHANGELOG.md`:

```markdown
# Changelog

## [1.1.0] - 2024-03-28

### Added
- Support for device verification with emoji SAS
- Improved error handling for crypto operations

### Fixed
- Fixed memory leak in device verification
- Corrected timestamp handling in encrypted messages

### Changed
- Updated matrix-sdk-crypto to v0.7.2
- Improved performance of encryption operations

## [1.0.0] - 2024-03-15

### Initial Release
- End-to-end encryption support for React Native
- iOS and Android support
- Device verification
```

#### 1.3 Update Documentation

Review and update:
- `README.md` - Installation and usage instructions
- `INTEGRATION.md` - Integration guide for apps
- `CHANGELOG.md` - Release notes

### Step 2: Local Testing

#### 2.1 Build All Platforms

```bash
cd matrix-crypto-bridge

# Build and package for all platforms
bash build-scripts/build-and-package.sh all
```

#### 2.2 Verify Package Contents

```bash
cd react-native-matrix-crypto

# Check that all files are present
ls -la ios/prebuilt/
ls -la android/src/main/jniLibs/*/

# Verify package.json and lib/ exist
npm run build
```

#### 2.3 Test in Fortress App

```bash
# Create local npm link
cd react-native-matrix-crypto
npm link

# Link in Fortress app
cd /path/to/fortress
npm link @k9o/react-native-matrix-crypto

# Install iOS pods
cd ios
pod install
cd ..

# Test on iOS
npm run dev:ios

# Test on Android
npm run dev:android

# Unlink when done
npm unlink @k9o/react-native-matrix-crypto
cd react-native-matrix-crypto
npm unlink
```

#### 2.4 Run Tests

```bash
cd react-native-matrix-crypto

# Run any available tests
npm test

# Type check
npm run type-check

# Lint
npm run lint
```

### Step 3: Commit and Tag

#### 3.1 Commit Changes

```bash
cd matrix-crypto-bridge

git add -A
git commit -m "chore: Release v1.1.0

- Updated matrix-sdk-crypto to v0.7.2
- Added device verification support
- Improved error handling
- Updated documentation"
```

#### 3.2 Create Git Tag

```bash
# Create annotated tag
git tag -a v1.1.0 -m "Release v1.1.0 - Device verification support"

# Push to GitHub
git push origin main
git push origin v1.1.0
```

### Step 4: Automated CI/CD Pipeline

The GitHub Actions workflow will automatically:

1. **Build iOS Libraries**
   - Builds for aarch64-apple-ios (device)
   - Builds for x86_64-apple-ios (simulator)

2. **Build Android Libraries**
   - Builds for aarch64-linux-android (ARM64)
   - Builds for armv7-linux-androideabi (ARMv7)
   - Builds for x86_64-linux-android (x86_64)

3. **Package for NPM**
   - Downloads all build artifacts
   - Organizes iOS libraries in `ios/prebuilt/`
   - Organizes Android libraries in `android/src/main/jniLibs/`
   - Builds TypeScript
   - Verifies package contents

4. **Publish to NPM**
   - Publishes the complete package to NPM
   - Creates GitHub Release with build information

### Step 5: Manual Publishing (if needed)

If you need to publish manually without a git tag:

```bash
cd react-native-matrix-crypto

# Ensure everything is built
npm run build

# Verify package contents
npm pack --dry-run

# Publish to NPM
npm publish --access public

# If publishing to a specific tag (e.g., beta)
npm publish --tag beta --access public
```

### Step 6: Verify Publication

#### 6.1 Check NPM Registry

```bash
# View package on NPM
npm view @k9o/react-native-matrix-crypto

# View specific version
npm view @k9o/react-native-matrix-crypto@1.1.0

# List all versions
npm view @k9o/react-native-matrix-crypto versions
```

#### 6.2 Test Installation

In a test directory:

```bash
# Create test project
mkdir test-install
cd test-install
npm init -y

# Install the package
npm install @k9o/react-native-matrix-crypto@1.1.0

# Verify files
ls -la node_modules/@k9o/react-native-matrix-crypto/
ls -la node_modules/@k9o/react-native-matrix-crypto/ios/prebuilt/
ls -la node_modules/@k9o/react-native-matrix-crypto/android/src/main/jniLibs/
```

#### 6.3 Test in Real App

```bash
# In Fortress app
npm install @k9o/react-native-matrix-crypto@1.1.0

# iOS
cd ios && pod install && cd ..
npm run dev:ios

# Android
npm run dev:android
```

## Release Checklist

- [ ] All tests pass locally
- [ ] Version updated in `package.json`
- [ ] `CHANGELOG.md` updated with release notes
- [ ] `README.md` and documentation reviewed
- [ ] No console warnings or errors in build
- [ ] iOS libraries built for both architectures
- [ ] Android libraries built for all architectures
- [ ] Package tested locally with `npm link`
- [ ] Package tested in Fortress app
- [ ] Git commit created with descriptive message
- [ ] Git tag created with version number
- [ ] Changes pushed to GitHub
- [ ] GitHub Actions workflow completed successfully
- [ ] Package published to NPM
- [ ] NPM package verified and accessible
- [ ] GitHub Release created with notes
- [ ] Documentation updated on GitHub

## Troubleshooting

### Build Fails on iOS

```bash
# Clean build
rm -rf target/
cargo clean

# Try again
cargo build --release --target aarch64-apple-ios
```

### Build Fails on Android

```bash
# Verify NDK is installed
echo $ANDROID_NDK_HOME

# Clean build
rm -rf target/
cargo clean

# Try again
./build-scripts/build-android.sh
```

### NPM Publish Fails

```bash
# Check authentication
npm whoami

# Login if needed
npm login

# Verify package.json is valid
npm pack --dry-run

# Try publishing again
npm publish --access public
```

### Package Not Found After Publishing

```bash
# NPM can take a few minutes to update
# Check registry directly
curl https://registry.npmjs.org/@k9o/react-native-matrix-crypto

# Or use npm
npm view @k9o/react-native-matrix-crypto
```

## Continuous Deployment

The GitHub Actions workflow automatically publishes when:

1. **Tag is pushed**: Any tag matching `v*` triggers the full pipeline
2. **Manual trigger**: Use `workflow_dispatch` with `publish: true`

To trigger manually:

```bash
# Via GitHub CLI
gh workflow run build-and-publish.yml -f publish=true

# Or via GitHub web interface:
# 1. Go to Actions tab
# 2. Select "Build and Publish to NPM"
# 3. Click "Run workflow"
# 4. Set "Publish to NPM" to true
```

## Rollback

If a bad release is published:

```bash
# Deprecate the bad version
npm deprecate @k9o/react-native-matrix-crypto@1.1.0 "This version has issues, use 1.1.1 instead"

# Or unpublish (only within 72 hours of publishing)
npm unpublish @k9o/react-native-matrix-crypto@1.1.0 --force
```

## Versioning Strategy

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0 → 2.0.0): Breaking changes
  - Incompatible API changes
  - Minimum OS version changes
  - Major Rust dependency updates

- **MINOR** (1.0.0 → 1.1.0): New features
  - New APIs
  - New supported architectures
  - Performance improvements

- **PATCH** (1.0.0 → 1.0.1): Bug fixes
  - Bug fixes
  - Security patches
  - Documentation updates

## Support

For issues or questions:

1. Check existing GitHub Issues
2. Create a new GitHub Issue with:
   - Package version
   - React Native version
   - Platform (iOS/Android)
   - Detailed error message
   - Steps to reproduce

## Resources

- [NPM Publishing Guide](https://docs.npmjs.com/packages-and-modules/contributing-packages-to-the-registry)
- [Semantic Versioning](https://semver.org/)
- [React Native Native Modules](https://reactnative.dev/docs/native-modules-intro)
- [CocoaPods Documentation](https://guides.cocoapods.org/)
- [Gradle Documentation](https://gradle.org/guides/)
